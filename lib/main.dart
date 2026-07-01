import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String yusufiApiBaseUrl = 'https://app.khanger1234.com/yusufi-api.php';

void main() {
  runApp(const YusufiApp());
}

class YusufiApp extends StatelessWidget {
  const YusufiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'خدمات یوسفی',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans',
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  YusufiConfig? config;
  bool loading = true;
  String? error;
  DateTime? lastUpdate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadConfig();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // هر بار برنامه دوباره باز شود یا از بک‌گراند برگردد، API تازه خوانده می‌شود.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadConfig(silent: true);
    }
  }

  Future<void> loadConfig({bool silent = false}) async {
    if (!silent) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final url = Uri.parse('$yusufiApiBaseUrl?t=$ts');

    try {
      final res = await http.get(
        url,
        headers: const {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      if (res.body.trim().isEmpty) {
        throw Exception('API_EMPTY_RESPONSE');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        throw Exception('API_INVALID_JSON');
      }

      final next = YusufiConfig.fromJson(decoded.cast<String, dynamic>());

      setState(() {
        config = next;
        loading = false;
        error = null;
        lastUpdate = DateTime.now();
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = 'اتصال به پنل برقرار نشد: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = config;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF0F766E),
              Color(0xFF134E4A),
              Color(0xFF052E2B),
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => loadConfig(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                HeaderCard(
                  title: c?.appTitle ?? 'خدمات یوسفی',
                  notice: c?.notice ?? 'در حال دریافت اطلاعات از پنل...',
                  lastUpdate: lastUpdate,
                  onRefresh: () => loadConfig(),
                ),
                const SizedBox(height: 14),
                if (loading && c == null) const LoadingCard(),
                if (error != null)
                  ErrorCard(
                    message: error!,
                    onRetry: () => loadConfig(),
                  ),
                if (c != null) ...[
                  InfoCard(
                    icon: Icons.currency_exchange,
                    title: 'نرخ / اطلاعیه',
                    value: c.exchangeText,
                  ),
                  const SizedBox(height: 12),
                  SupportCard(
                    whatsapp: c.whatsapp,
                    imo: c.imo,
                  ),
                  const SizedBox(height: 12),
                  ServicesCard(services: c.services),
                  const SizedBox(height: 12),
                  ApiStatusCard(config: c),
                ],
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'اطلاعات این برنامه مستقیم از پنل مادر خوانده می‌شود',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class YusufiConfig {
  final bool success;
  final String appTitle;
  final String notice;
  final String exchangeText;
  final String whatsapp;
  final String imo;
  final String endpoint;
  final bool dynamicLink;
  final List<YusufiService> services;

  const YusufiConfig({
    required this.success,
    required this.appTitle,
    required this.notice,
    required this.exchangeText,
    required this.whatsapp,
    required this.imo,
    required this.endpoint,
    required this.dynamicLink,
    required this.services,
  });

  factory YusufiConfig.fromJson(Map<String, dynamic> json) {
    final rawOptions = asMap(json['raw_options']);

    final services = <YusufiService>[];
    final seen = <String>{};

    void addService(String key, String name, bool enabled) {
      final cleanName = name.trim();
      final cleanKey = key.trim().isEmpty ? cleanName : key.trim();

      if (cleanName.isEmpty) return;
      if (!enabled) return;
      if (seen.contains(cleanKey)) return;

      seen.add(cleanKey);
      services.add(YusufiService(
        key: cleanKey,
        name: cleanName,
        enabled: enabled,
      ));
    }

    void readList(dynamic source) {
      if (source is! List) return;

      for (final item in source) {
        if (item is String) {
          addService(item, item, true);
        } else if (item is Map) {
          final m = item.map((k, v) => MapEntry(k.toString(), v));
          final name = '${m['name'] ?? m['title'] ?? m['label'] ?? ''}';
          final key = '${m['key'] ?? name}';
          final enabled = readBool(m['enabled'] ?? m['is_enabled'], true);
          addService(key, name, enabled);
        }
      }
    }

    readList(rawOptions['yusufi_services']);
    readList(json['yusufi_services']);
    readList(json['services']);
    readList(json['modules']);

    if (services.isEmpty) {
      addService('transfer', 'حواله ایران ↔ افغانستان', true);
      addService('mobile', 'شارژ موبایل', true);
      addService('vpn', 'خدمات VPN', true);
      addService('game', 'خدمات بازی PUBG / UC', true);
      addService('support', 'پشتیبانی آنلاین', true);
    }

    return YusufiConfig(
      success: readBool(json['success'], true),
      appTitle: readString(
        json,
        rawOptions,
        ['app_title', 'title', 'yusufi_app_title'],
        'خدمات یوسفی',
      ),
      notice: readString(
        json,
        rawOptions,
        ['notice', 'message', 'yusufi_notice'],
        'به اپ خدمات یوسفی خوش آمدید',
      ),
      exchangeText: readString(
        json,
        rawOptions,
        ['exchange_text', 'exchange', 'rate_text', 'yusufi_exchange_text'],
        'نرخ هنوز از پنل تنظیم نشده است',
      ),
      whatsapp: readString(
        json,
        rawOptions,
        ['whatsapp', 'support_whatsapp', 'yusufi_whatsapp'],
        '',
      ),
      imo: readString(
        json,
        rawOptions,
        ['imo', 'support_imo', 'yusufi_imo'],
        '',
      ),
      endpoint: '${json['endpoint'] ?? ''}',
      dynamicLink: readBool(json['dynamic_link'], false),
      services: services,
    );
  }

  static Map<String, dynamic> asMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }

  static bool readBool(dynamic value, bool fallback) {
    if (value == null) return fallback;
    if (value is bool) return value;

    final text = value.toString().trim().toLowerCase();

    if (text == '1' || text == 'true' || text == 'yes' || text == 'on') {
      return true;
    }

    if (text == '0' || text == 'false' || text == 'no' || text == 'off') {
      return false;
    }

    return fallback;
  }

  static String readString(
    Map<String, dynamic> root,
    Map<String, dynamic> options,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final v1 = root[key];
      if (v1 != null && v1.toString().trim().isNotEmpty) {
        return v1.toString();
      }

      final v2 = options[key];
      if (v2 != null && v2.toString().trim().isNotEmpty) {
        return v2.toString();
      }
    }

    return fallback;
  }
}

class YusufiService {
  final String key;
  final String name;
  final bool enabled;

  const YusufiService({
    required this.key,
    required this.name,
    required this.enabled,
  });
}

class HeaderCard extends StatelessWidget {
  final String title;
  final String notice;
  final DateTime? lastUpdate;
  final VoidCallback onRefresh;

  const HeaderCard({
    super.key,
    required this.title,
    required this.notice,
    required this.lastUpdate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final timeText = lastUpdate == null
        ? 'در حال دریافت'
        : '${lastUpdate!.hour.toString().padLeft(2, '0')}:${lastUpdate!.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                child: Icon(Icons.apps, color: Color(0xFF0F766E)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            notice,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Text(
            'آخرین دریافت از پنل: $timeText',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('در حال خواندن اطلاعات از پنل...')),
          ],
        ),
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('خطا در اتصال',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش دوباره'),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0F766E)),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class SupportCard extends StatelessWidget {
  final String whatsapp;
  final String imo;

  const SupportCard({
    super.key,
    required this.whatsapp,
    required this.imo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('پشتیبانی',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SupportRow(
              icon: Icons.chat,
              label: 'واتساپ',
              value: whatsapp.isEmpty ? 'از پنل تنظیم نشده' : whatsapp,
            ),
            const SizedBox(height: 8),
            SupportRow(
              icon: Icons.phone_in_talk,
              label: 'ایمو',
              value: imo.isEmpty ? 'از پنل تنظیم نشده' : imo,
            ),
          ],
        ),
      ),
    );
  }
}

class SupportRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const SupportRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0F766E)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class ServicesCard extends StatelessWidget {
  final List<YusufiService> services;

  const ServicesCard({
    super.key,
    required this.services,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('خدمات فعال',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final service in services)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF0F766E)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        service.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ApiStatusCard extends StatelessWidget {
  final YusufiConfig config;

  const ApiStatusCard({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const Icon(Icons.cloud_done, color: Color(0xFF0F766E)),
        title: const Text('وضعیت اتصال پنل'),
        subtitle: Text(
          config.dynamicLink
              ? 'اتصال داینامیک فعال است'
              : 'اتصال برقرار است، اما dynamic_link در JSON دیده نشد',
        ),
      ),
    );
  }
}
