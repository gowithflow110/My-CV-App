// lib/services/cv_parser.dart
class CVParser {
  // Public entry point
  static Map<String, dynamic> refine(Map<String, dynamic> raw) {
    // Normalize raw inputs
    final nameRaw = _asSingleString(raw['name']);
    final contactRaw = _asList(raw['contact']);
    final educationRaw = _asList(raw['education']);
    final skillsRaw = _asList(raw['skills']);
    final languagesRaw = _asList(raw['languages']);
    final certsRaw = _asList(raw['certifications']);
    final expRaw = _asList(raw['experience']);
    final projectsRaw = _asList(raw['projects']);
    final summaryRaw = _asSingleString(raw['summary']);

    // Parse each section
    final fullName = _extractName(nameRaw, raw['dbName']);
    final contact = _parseContact(contactRaw);
    final skills = _parseSkills(skillsRaw);
    final languages = _parseLanguages(languagesRaw);
    final education = _parseEducation(educationRaw);
    final experience = _parseExperience(expRaw);
    final projects = _parseProjects(projectsRaw);
    final certifications = _parseCerts(certsRaw);

    // Summary enhancement
    final summary = _buildSummary(
      userSummary: summaryRaw,
      name: fullName,
      skills: skills,
      experience: experience,
      education: education,
    );

    // Final schema-compliant output
    return ensureTemplateCompliance({
      'fullName': fullName,
      'summary': summary,
      'contact': contact,
      'skills': skills,
      'experience': experience,
      'education': education,
      'projects': projects,
      'certifications': certifications,
      'languages': languages,
    });
  }

  // ------------------- helpers -------------------

  static String _asSingleString(dynamic v) {
    if (v == null) return '';
    if (v is String) return v.trim();
    if (v is List) return v.join(' ').trim();
    return v.toString().trim();
  }

  static List<String> _asList(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v
          .map((e) => e?.toString() ?? '')
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    if (v is String) return [v.trim()].where((s) => s.isNotEmpty).toList();
    return [v.toString()];
  }

  static bool _isNonsense(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty) return true;
    if (t == '...' || t == 'n/a') return true;
    if (!RegExp(r'[a-zA-Z]').hasMatch(t)) return true;
    if (t.length < 2) return true;
    return false;
  }

  static String _titleCase(String input) {
    return input
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty
            ? w
            : w[0].toUpperCase() +
                (w.length > 1 ? w.substring(1).toLowerCase() : ''))
        .join(' ')
        .trim();
  }

  // -------- Name --------
  static String _extractName(String raw, dynamic dbName) {
    if (_isNonsense(raw)) {
      if (dbName is String && dbName.trim().isNotEmpty) {
        return _titleCase(dbName.trim());
      }
      return '';
    }
    final m = RegExp(r'(my\s+name\s+is|i\s*am|this\s+is)\s+(.+)',
            caseSensitive: false)
        .firstMatch(raw);
    final name = _titleCase((m != null ? m.group(2) : raw).toString());
    return name
        .replaceAll(RegExp(r"[^a-zA-Z\s\-\']"), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // -------- Contact --------
  static Map<String, String> _parseContact(List<String> lines) {
    String email = '';
    String phone = '';
    String location = '';
    String linkedin = '';
    String website = '';
    String github = '';

    for (final l in lines) {
      final line = l.trim();
      if (_isNonsense(line)) continue;

      // Email
      final e = _emailRe.firstMatch(line);
      if (e != null && email.isEmpty) {
        email = e.group(0)!;
        continue;
      }

      // Phone
      final p = _phoneRe.firstMatch(line);
      if (p != null && phone.isEmpty) {
        phone = p.group(0)!;
        continue;
      }

      // LinkedIn
      final ln = _linkedInRe.firstMatch(line);
      if (ln != null && linkedin.isEmpty) {
        linkedin = ln.group(0)!.startsWith('http')
            ? ln.group(0)!
            : 'https://${ln.group(0)!}';
        continue;
      }

      // GitHub
      final gh = _githubRe.firstMatch(line);
      if (gh != null && github.isEmpty) {
        github = gh.group(0)!.startsWith('http')
            ? gh.group(0)!
            : 'https://${gh.group(0)!}';
        continue;
      }

      // Website (exclude linkedin/github/email)
      final web = _urlRe.firstMatch(line);
      if (web != null &&
          !line.contains('@') && // 🔹 skip if it’s an email
          !web.group(0)!.contains('linkedin') &&
          !web.group(0)!.contains('github') &&
          website.isEmpty) {
        website = web.group(0)!.startsWith('http')
            ? web.group(0)!
            : 'https://${web.group(0)!}';
        continue;
      }

      // Location (generic, no hardcoding)
      final addrMatch = RegExp(
        r'(address\s*[:\-]?\s*|i\s*live\s*in\s*|i\s*am\s*from\s*|i\s*reside\s*at\s*|located\s*at\s*)(.+)',
        caseSensitive: false,
      ).firstMatch(line);

      if (addrMatch != null) {
        // Take the full address after the keyword
        location = _titleCase(addrMatch.group(2)!.trim());
      } else {
        // If no keyword, but line looks like an address (letters + commas + numbers)
        if (RegExp(r'^[a-zA-Z0-9\s,.-]+$').hasMatch(line) &&
            line.split(' ').length >= 2 &&
            location.isEmpty &&
            !line.contains('@') && // skip emails
            !_phoneRe.hasMatch(line)) {
          // skip phone numbers
          location = _titleCase(line.trim());
        }
      }
    }

    return {
      'email': email,
      'phone': phone,
      'location': location,
      'linkedin': linkedin,
      'website': website,
      'github': github,
    }..removeWhere((k, v) => v.toString().trim().isEmpty);
  }

  static final RegExp _emailRe = RegExp(
    r'[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}',
    caseSensitive: false,
  );

  static final RegExp _phoneRe = RegExp(
    r'(?:(?:\+|00)\d{1,3}[\s\-\.\)]*)?(?:\(?\d{2,4}\)?[\s\-\.\)]*)?\d{3,4}[\s\-\.\)]*\d{3,5}(?:\s*(?:x|ext\.?|extension)\s*\d{1,5})?',
    caseSensitive: false,
  );

  static final RegExp _linkedInRe = RegExp(
    r'(https?:\/\/)?(www\.)?linkedin\.com\/in\/[A-Za-z0-9\-_\.]+',
    caseSensitive: false,
  );

  static final RegExp _githubRe = RegExp(
    r'(https?:\/\/)?(www\.)?github\.com\/[A-Za-z0-9\-_\.]+',
    caseSensitive: false,
  );

  static final RegExp _urlRe = RegExp(
    r'(?:(?:https?:\/\/)?(?:www\.)?[A-Za-z0-9\-]{2,}\.[A-Za-z]{2,}(?:[\/\w\-\.\?\=\#\&\%]*)?)',
    caseSensitive: false,
  );

  // -------- Skills --------
  static List<String> _parseSkills(List<String> lines) {
    final out = <String>[];
    for (final l in lines) {
      if (_isNonsense(l)) continue;
      var s = l.toLowerCase();
      s = s.replaceAll(RegExp(r'^(i\s*(am|have|know|do)\s*)'), '');
      final parts = s.split(RegExp(r'[,\uFF0C]| and '));
      for (var p in parts) {
        p = p.trim();
        if (p.isEmpty) continue;
        p = p.replaceAll(RegExp(r'^(a|an|the)\s+'), '').trim();
        if (_isNonsense(p)) continue;
        out.add(_titleCase(p));
      }
    }
    return out.toSet().toList();
  }

  // -------- Languages --------
  static List<String> _parseLanguages(List<String> lines) {
    final out = <String>[];
    for (final l in lines) {
      if (_isNonsense(l)) continue;
      var s =
          l.toLowerCase().replaceAll(RegExp(r'^(i\s*(can\s*)?speak\s*)'), '');
      final parts = s.split(RegExp(r'[,\uFF0C]| and '));
      for (var p in parts) {
        p = p.trim();
        if (_isNonsense(p)) continue;
        p = p.replaceAll(RegExp(r'[^a-zA-Z\s\-]'), '');
        out.add(_titleCase(p));
      }
    }
    return out.where((x) => x.length >= 2).toSet().toList();
  }

// -------- Education --------
static List<Map<String, dynamic>> _parseEducation(List<String> lines) {
  final out = <Map<String, dynamic>>[];

  for (final l in lines) {
    if (_isNonsense(l)) continue;
    final line = l.trim();

    // Extract year
    final year = RegExp(r'(20\d{2}|19\d{2})').firstMatch(line)?.group(0) ?? '';

    // 🔹 Extract degree dynamically (preserve full phrase)
    String degree = '';
    final degreeMatch = RegExp(
      r'(done|completed|studied|study|pursued|graduated\s+with|earned|have\s+done)\s+(.+?)(\s+from|\s+at|\s+in|,|$)',
      caseSensitive: false,
    ).firstMatch(line);

    if (degreeMatch != null) {
      degree = _titleCase(degreeMatch.group(2)!.trim());
    } else {
      // Case 2: Direct mentions like "BS Computer Science", "FSc Pre Engineering", "Matric"
      final directRe = RegExp(
        r'\b(matric|intermediate|f\.?a\.?|f\.?sc\.?|ics|i\.com|'
        r"bachelor(?:'s)?(?: of)?|bs|bsc|ba|"
        r"master(?:'s)?(?: of)?|ms|msc|ma|"
        r'phd|doctorate)\b(?:\s+(?:in\s+)?([A-Za-z\s]+))?',
        caseSensitive: false,
      );
      final directMatch = directRe.firstMatch(line);
      if (directMatch != null) {
        final base = _titleCase(directMatch.group(1)!);
        final subject = directMatch.group(2);
        degree = subject != null && subject.trim().isNotEmpty
            ? "$base in ${_titleCase(subject.trim())}"
            : base;
      } else {
        // Case 3: fallback "degree in X"
        final fallback =
            RegExp(r'degree\s+in\s+(.+)', caseSensitive: false).firstMatch(line);
        if (fallback != null) {
          degree = _titleCase(fallback.group(1)!.trim());
        }
      }
    }

    // Extract institution
    String institution = '';
    String location = '';
    final instM =
        RegExp(r'(from|at)\s+(.+)', caseSensitive: false).firstMatch(line);
    if (instM != null) {
      final instFull = instM.group(2)!.trim();
      if (instFull.contains(',')) {
        final parts = instFull.split(',');
        institution = _titleCase(parts[0]);
        location = _titleCase(parts.sublist(1).join(',').trim());
      } else {
        institution = _titleCase(instFull);
      }
    }

    // Extract GPA / Marks
    String gpa = '';
    final gpaMatch = RegExp(
      r'(\d+(\.\d+)?\s*\/\s*\d+|\d+(\.\d+)?\s*gpa|\d+(\.\d+)?%|\d+\s*out\s*of\s*\d+)',
      caseSensitive: false,
    ).firstMatch(line);
    if (gpaMatch != null) {
      gpa = gpaMatch.group(0)!
          .replaceAll(RegExp(r'(gpa|marks|out of)', caseSensitive: false), '')
          .trim();
    }

    if (degree.isEmpty && institution.isEmpty && gpa.isEmpty) continue;

    out.add({
      'degree': degree,
      'institution': institution,
      'year': year,
      'location': location,
      'gpa': gpa,
    }..removeWhere((k, v) => v.toString().trim().isEmpty));
  }

  return out;
}


  // -------- Experience --------
  static List<Map<String, dynamic>> _parseExperience(List<String> lines) {
    final out = <Map<String, dynamic>>[];
    for (final l in lines) {
      if (_isNonsense(l)) continue;
      var line = l.trim();
      String role = '';
      final m1 = RegExp(
              r'(worked\s+as|as|i\s*was|position\s*:\s*)(.+?)( at| in| for|,|$)',
              caseSensitive: false)
          .firstMatch(line);
      if (m1 != null) role = m1.group(2)!.trim();

      String company = '';
      final m2 =
          RegExp(r'(at|in)\s+([A-Za-z0-9\-\&\.\s]+)', caseSensitive: false)
              .firstMatch(line);
      if (m2 != null) company = m2.group(2)!.trim();

      String location = '';
      final locMatch = RegExp(
              r'(karachi|lahore|islamabad|mansehra|peshawar|rawalpindi)',
              caseSensitive: false)
          .firstMatch(line);
      if (locMatch != null) location = _titleCase(locMatch.group(0)!);

      String startDate = '';
      String endDate = '';
      final m4 = RegExp(r'(\b20\d{2}\b).*(\b20\d{2}\b)').firstMatch(line);
      if (m4 != null) {
        startDate = m4.group(1)!;
        endDate = m4.group(2)!;
      }

      if (role.isEmpty &&
          company.isEmpty &&
          startDate.isEmpty &&
          endDate.isEmpty) continue;

      // Generate AI-like enhanced bullet points
      final bullets = <String>[];

      if (role.isNotEmpty) {
        bullets.add(
          'Effectively applied expertise as ${_titleCase(role)} at ${_titleCase(company)}, gaining valuable hands-on experience and strengthening both technical and interpersonal skills.',
        );
        bullets.add(
          'Led initiatives and contributed to achieving organizational goals, while adapting to dynamic challenges within the role of ${_titleCase(role)}.',
        );
      }

      if (company.isNotEmpty) {
        bullets.add(
          'Collaborated with diverse teams at ${_titleCase(company)}, ensuring smooth coordination across departments and delivering meaningful results.',
        );
        bullets.add(
          'Contributed to the long-term growth of ${_titleCase(company)} by consistently maintaining professional standards and delivering on key responsibilities.',
        );
      }

      if (location.isNotEmpty) {
        bullets.add(
          'Built professional experience in ${location}, adapting effectively to the regional work environment and culture.',
        );
      }

      if (startDate.isNotEmpty || endDate.isNotEmpty) {
        bullets.add(
          'Gained progressive experience between $startDate and ${endDate.isNotEmpty ? endDate : "present"}, focusing on continuous learning and performance improvement.',
        );
      }

      // Fallback if nothing specific
      if (bullets.isEmpty) {
        bullets.addAll([
          'Contributed effectively to organizational objectives by performing assigned duties with commitment and responsibility.',
          'Strengthened communication, problem-solving, and teamwork abilities through active participation in professional tasks and collaborations.',
        ]);
      }

      out.add({
        'title': _titleCase(role),
        'company': _titleCase(company),
        'location': location,
        'startDate': startDate,
        'endDate': endDate,
        'duration': '',
        'details': bullets,
      }..removeWhere((k, v) => v is String && v.trim().isEmpty));
    }
    return out;
  }

  // -------- Projects --------
  static List<Map<String, dynamic>> _parseProjects(List<String> lines) {
    final out = <Map<String, dynamic>>[];
    for (final l in lines) {
      if (_isNonsense(l)) continue;
      final name = _titleCase(
          l.split(RegExp(r' in | using | with | for ')).first.trim());
      out.add({
        'name': name,
        'description':
            'Developed $name using modern tools and best practices to deliver high-quality results.'
      });
    }
    return out;
  }

  // -------- Certifications --------
  static List<Map<String, dynamic>> _parseCerts(List<String> lines) {
    final out = <Map<String, dynamic>>[];
    for (final l in lines) {
      if (_isNonsense(l)) continue;
      final line = l.trim();
      final year =
          RegExp(r'(20\d{2}|19\d{2})').firstMatch(line)?.group(0) ?? '';
      var title = _titleCase(line
          .replaceAll(RegExp(r'(from|by)\s+.*$'), '')
          .replaceAll(year, '')
          .trim());
      String issuer = '';
      final im =
          RegExp(r'(from|by)\s+(.+)', caseSensitive: false).firstMatch(line);
      if (im != null) issuer = _titleCase(im.group(2)!.trim());
      out.add({
        'title': title,
        'issuer': issuer,
        'date': year,
      }..removeWhere((k, v) => v.toString().trim().isEmpty));
    }
    return out;
  }

  // -------- Summary --------
  static String _buildSummary({
    required String userSummary,
    required String name,
    required List<String> skills,
    required List<Map<String, dynamic>> experience,
    required List<Map<String, dynamic>> education,
  }) {
    if (!_isNonsense(userSummary)) return userSummary.trim();
    final skill = skills.isNotEmpty ? skills.first : 'Motivated professional';
    final expYears = experience.isNotEmpty ? 'with hands-on experience' : '';
    return '${_titleCase(skill)} $expYears in modern development practices.';
  }

  // -------- Template compliance --------
  static Map<String, dynamic> ensureTemplateCompliance(
      Map<String, dynamic> json) {
    final Map<String, dynamic> result = Map<String, dynamic>.from(json);

    final Map<String, dynamic> defaults = {
      'fullName': '',
      'summary': '',
      'contact': {
        'email': '',
        'phone': '',
        'location': '',
        'linkedin': '',
        'website': '',
        'github': '',
      },
      'skills': <String>[],
      'experience': <Map<String, dynamic>>[],
      'education': <Map<String, dynamic>>[],
      'projects': <Map<String, dynamic>>[],
      'certifications': <Map<String, dynamic>>[],
      'languages': <String>[],
    };

    for (final entry in defaults.entries) {
      if (!result.containsKey(entry.key)) {
        result[entry.key] = entry.value;
      }
    }

    if (result['contact'] is! Map) {
      result['contact'] = Map<String, String>.from(defaults['contact']);
    } else {
      final contactDefaults = Map<String, String>.from(defaults['contact']);
      final contactIncoming = Map<String, String>.from(
        Map<String, dynamic>.from(result['contact'])
            .map((k, v) => MapEntry(k, v?.toString() ?? '')),
      );
      contactDefaults.addAll(contactIncoming);
      result['contact'] = contactDefaults;
    }

    return result;
  }
}
