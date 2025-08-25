/// lib/services/ai_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

enum AIProvider { gemini, openai, huggingface }

class AIService {
  final String _openAIApiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  final String _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  final String _huggingFaceApiKey = dotenv.env['HUGGINGFACE_API_KEY'] ?? '';

  String lastProviderUsed = "";

  // ---------------------------------------------------------------------------
  // NEW: Primary entry for your flow — ask AI to return a refined JSON object
  //      that matches the template schema exactly.
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> polishCVAsJson(
    Map<String, dynamic> refinedInput,
  ) async {
    final prompt = _buildPolishJsonPrompt(refinedInput);

    final raw = await _tryProviders(prompt, expectJsonOnly: true);

    // Clean & parse JSON safely
    final jsonText = _extractJson(raw);
    try {
      final parsed = json.decode(jsonText);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      } else {
        throw Exception('AI did not return a JSON object.');
      }
    } catch (e) {
      debugPrint('❌ JSON parse error: $e');
      throw Exception('Failed to parse AI JSON output.');
    }
  }

  // ---------------------------------------------------------------------------
  // Existing polishCV: keep it (text output). You can still use it if needed.
  // ---------------------------------------------------------------------------
  Future<String> polishCV(Map<String, dynamic> cvData) async {
    final prompt = _buildPolishPrompt(cvData);

    try {
      lastProviderUsed = "Gemini";
      return await _callGemini(prompt);
    } catch (_) {
      try {
        lastProviderUsed = "OpenAI";
        return await _callOpenAI(prompt);
      } catch (_) {
        try {
          lastProviderUsed = "Hugging Face";
          return await _callHuggingFace(prompt);
        } catch (_) {
          lastProviderUsed = "None";
          return "We encountered an issue processing your CV. Please try again later.";
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Existing helpers (summary, bullets) — unchanged
  // ---------------------------------------------------------------------------
  Future<String> polishSummary(String summary) async {
    if (summary.trim().isEmpty) return "";

    final prompt = """
Rewrite and expand this CV summary to be 3–4 impactful lines for an A4 CV.
Make it professional, clear, and ATS-friendly.
Do NOT invent experience — only rephrase and expand what's provided.

Summary:
$summary
""";

    return await _tryProviders(prompt);
  }

Future<List<String>> generateExperienceBullets(Map<String, dynamic> exp) async {
  final role = exp['title'] ?? '';
  final company = exp['company'] ?? '';
  final notes = (exp['details'] is List)
      ? (exp['details'] as List).join(" ")
      : (exp['details']?.toString() ?? '');

  final prompt = """
You are a professional CV writer.
Generate 4–6 detailed and achievement-oriented bullet points for this work experience.

Guidelines:
- Each bullet MUST be a full sentence (20–30 words).
- Use strong action verbs (Led, Spearheaded, Designed, Implemented, Engineered, Optimized, Delivered, Reduced, Increased).
- Quantify results with metrics (% improvements, cost savings, revenue growth, efficiency gains, team size, timelines) whenever possible.
- Tailor the bullets to the role ($role) and company ($company).
- Avoid vague filler like "helped" or "worked on".
- Do NOT repeat the same structure for every bullet.
- Do NOT invent unrelated achievements, but expand using context provided.

Role: $role
Company: $company
Details/context: $notes
""";

  final raw = await _tryProviders(prompt);

  final bullets = raw
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'^[-•]\s*'), '').trim())
      .where((line) => line.isNotEmpty)
      .toList();

  // Return up to 6 longer bullets
  return bullets.take(6).toList();
}


  // ---------------------------------------------------------------------------
  // NEW: “expectJsonOnly” flag to harden output when we need raw JSON.
  // ---------------------------------------------------------------------------
  Future<String> _tryProviders(String prompt, {bool expectJsonOnly = false}) async {
    try {
      lastProviderUsed = "Gemini";
      return await _callGemini(prompt, expectJsonOnly: expectJsonOnly);
    } catch (_) {
      try {
        lastProviderUsed = "OpenAI";
        return await _callOpenAI(prompt, expectJsonOnly: expectJsonOnly);
      } catch (_) {
        lastProviderUsed = "Hugging Face";
        return await _callHuggingFace(prompt);
      }
    }
  }

  // ---------- Gemini ----------
  Future<String> _callGemini(String prompt, {bool expectJsonOnly = false}) async {
    if (_geminiApiKey.isEmpty) throw Exception("Gemini API key not set.");

    Future<String> sendRequest(String model) async {
      final url =
          "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_geminiApiKey";

      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ],
          if (expectJsonOnly)
            // Gemini tolerates this hint in prompt better than forcing JSON mode.
            "generationConfig": {
              "temperature": 0.2,
            },
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Gemini API failed ($model): ${response.body}");
      }

      final jsonResponse = jsonDecode(response.body);
      final candidates = jsonResponse["candidates"];
      if (candidates is List && candidates.isNotEmpty) {
        final parts = candidates.first["content"]?["parts"];
        if (parts is List && parts.isNotEmpty && parts.first["text"] is String) {
          return parts.first["text"].trim();
        }
      }
      throw Exception("Unexpected Gemini API response format ($model)");
    }

    try {
      return await sendRequest("gemini-1.5-pro");
    } catch (e) {
      if (e.toString().contains("RESOURCE_EXHAUSTED") ||
          e.toString().contains("429") ||
          e.toString().contains("NOT_FOUND")) {
        return await sendRequest("gemini-1.5-flash");
      }
      rethrow;
    }
  }

  // ---------- OpenAI ----------
  Future<String> _callOpenAI(String prompt, {bool expectJsonOnly = false}) async {
    if (_openAIApiKey.isEmpty) throw Exception("OpenAI API key not set.");

    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_openAIApiKey",
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",
        "messages": [
          {
            "role": "system",
            "content": expectJsonOnly
                ? "You are a strict JSON generator. Respond with valid JSON only, no markdown, no comments."
                : "You are a professional CV writer."
          },
          {"role": "user", "content": prompt}
        ],
        "temperature": expectJsonOnly ? 0.2 : 0.5,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("OpenAI API failed: ${response.body}");
    }

    final jsonResponse = jsonDecode(response.body);
    final choice = jsonResponse["choices"]?.first;
    final content = choice?["message"]?["content"];
    if (content is String) return content.trim();

    throw Exception("Unexpected OpenAI API response format");
  }

  // ---------- Hugging Face (fallback, text only) ----------
  Future<String> _callHuggingFace(String prompt) async {
    if (_huggingFaceApiKey.isEmpty) throw Exception("Hugging Face API key not set.");

    final url = "https://api-inference.huggingface.co/models/google/flan-t5-xl";

    final response = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_huggingFaceApiKey",
      },
      body: jsonEncode({
        "inputs": prompt,
        "parameters": {"max_length": 1024, "temperature": 0.5}
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Hugging Face API failed: ${response.body}");
    }

    final jsonResponse = jsonDecode(response.body);
    if (jsonResponse is List && jsonResponse.isNotEmpty) {
      final first = jsonResponse.first;
      if (first is Map && first["generated_text"] is String) {
        return first["generated_text"].trim();
      }
    }
    throw Exception("Unexpected Hugging Face API response format");
  }

  // ---------------------------------------------------------------------------
  // Prompts
  // ---------------------------------------------------------------------------

  // Plain text improve (kept from your code)
  String _buildPolishPrompt(Map<String, dynamic> cvData) {
    final sb = StringBuffer();
    sb.writeln("Please improve the wording of this CV text.");
    sb.writeln("Do NOT remove sections, change order, or add guessed information.\n");

    cvData.forEach((key, value) {
      sb.writeln("$key:");
      if (value is List) {
        for (var item in value) {
          sb.writeln("- $item");
        }
      } else {
        sb.writeln("$value");
      }
      sb.writeln();
    });

    return sb.toString();
  }

// Strict JSON output that matches our template layout exactly.
String _buildPolishJsonPrompt(Map<String, dynamic> refined) {
  final inputJson = const JsonEncoder.withIndent('  ').convert(refined);

  // Schema note: keep keys EXACTLY as below — this is what the TemplateService/Preview expect.
  return """
You are an expert CV editor. 
Task: Improve wording, grammar, and clarity. Reformat dates if helpful, but DO NOT invent facts. 
Return **VALID JSON ONLY** (no markdown fences, no comments). 
Ensure it matches EXACTLY this schema:

{
  "fullName": string,
  "summary": string,
  "contact": {
    "email": string?,
    "phone": string?,
    "location": string?,
    "linkedin": string?,
    "website": string?,
    "github": string?
  },
  "skills": string[],
  "experience": [
    {
      "title": string?,
      "company": string?,
      "location": string?,
      "startDate": string?,
      "endDate": string?,
      "duration": string?,
      "details": string[]
    }
  ],
  "education": [
    {
      "degree": string?,
      "institution": string?,
      "year": string?,
      "location": string?
      "gpa": string?   // ✅ new field for GPA/Marks
    }
  ],
  "projects": [
    {
      "name": string?,
      "description": string?
    }
  ],
  "certifications": [
    {
      "title": string?,
      "issuer": string?,
      "date": string?
    }
  ],
  "languages": string[]
}

Special summary rules:
- Rewrite "summary" into a concise, professional 2–3 sentence career statement.
- Make it clear, engaging, and ATS-friendly.
- Emphasize skills, experience level, and professional strengths.
- Avoid generic filler like "I am" or "looking for opportunities".
- If the input is too short, expand it using only existing context.

Experience rules:
- For each experience, expand "details" into 4–6 detailed, professional, achievement-oriented bullet points.
- Each bullet must be a complete sentence (20–30 words).
- Use strong action verbs (Led, Designed, Implemented, Spearheaded, Optimized, Delivered, Reduced, Increased).
- Quantify results with metrics (% improvements, cost savings, revenue growth, efficiency gains, timelines, team size) whenever possible.
- Tailor bullets to the role and company; avoid generic filler like "worked on" or "helped".
- Do NOT invent unrelated achievements, but refine and expand using only the provided context.

Project rules:
- Keep the "name" as a short, clear project title.
- Expand the "description" into 1–2 full sentences in professional English.
- Ensure descriptions highlight purpose, impact, or technologies used.
- Use proper grammar, enhanced clarity, and strong wording.
- Avoid overly generic phrases like "worked on a project" — make it meaningful and specific to the context provided.
- Do NOT invent unrelated features; only refine and expand based on input.

General rules:
- Keep the same information; improve phrasing only.
- Use title case for proper nouns and roles when appropriate.
- If a value is unknown, omit the key or leave empty string.
- If any GitHub link or mention is found, ensure it is placed in contact.github.
- Respond with JSON only.


Input JSON to refine:
$inputJson
""";
}


  // ---------------------------------------------------------------------------
  // JSON cleanup helpers
  // ---------------------------------------------------------------------------

  // Extract JSON from possible fenced text or helper text.
  String _extractJson(String raw) {
    var s = raw.trim();

    // Strip ```json ... ``` or ``` ... ```
    final fence = RegExp(r"^```(?:json)?\s*([\s\S]*?)\s*```$");
    final m = fence.firstMatch(s);
    if (m != null && m.groupCount >= 1) {
      s = m.group(1)!.trim();
    }

    // Common cleanup: remove trailing commas before ] or }
    s = s.replaceAll(RegExp(r",\s*([}\]])"), r"$1");

    // Some models prepend labels. Try to find the first { ... } block.
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      s = s.substring(start, end + 1);
    }
    return s;
  }
}
