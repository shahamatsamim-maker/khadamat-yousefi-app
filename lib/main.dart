
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String apiUrl = 'https://app.khanger1234.com/wp-json/yusufi/v1/config';

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
        scaffoldBackgroundColor: const Color(0xfff3f6fb),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomePage(),
      ),
    );
  }
}

class AppConfig {
  final String title;
  final String notice;
  final String exchangeText;
  final String whatsapp;
  final String imo;
  final List<ServiceItem> services;

  AppConfig({
    required this.title,
    required this.notice,
    required this.exchangeText,
    required this.whatsapp,
    required this.imo,
    required this.services,
  });

  factory AppConfig.empty() {
    return AppConfig(
      title: 'خدمات یوسفی',
      notice: 'در حال دریافت اطلاعات از پنل...',
      exchangeText: 'در حال دریافت نرخ ارز...',
      whatsapp: '',
      imo: '',
      services: const [],
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys, String fallback) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return fallback;
    }

    final list = <ServiceItem>[];
    final rawServices = json['services'];

    if (rawServices is List) {
      for (final item in rawServices) {
        final service = ServiceItem.fromJson(item);
        if (service.name.trim().isNotEmpty && service.enabled) {
          list.add(service);
        }
      }
    }

    return AppConfig(
      title: pick(['title', 'app_title', 'appTitle'], 'خدمات یوسفی'),
      notice: pick(['notice', 'message', 'app_notice'], 'به خدمات یوسفی خوش آمدید'),
      exchangeText: pick(
        ['exchange_text', 'exchange', 'exchangeText', 'rate_text', 'rateText'],
        'نرخ ارز دریافت نشد',
      ),
      whatsapp: pick(['whatsapp', 'whatsapp_number'], ''),
      imo: pick(['imo', 'imo_number'], ''),
      services: list,
    );
  }
}

class ServiceItem {
  final String name;
  final bool enabled;

  ServiceItem({
    required this.name,
    required this.enabled,
  });

  factory ServiceItem.fromJson(dynamic item) {
    if (item is String) {
      return ServiceItem(name: item, enabled: true);
    }

    if (item is Map) {
      final name = (item['name'] ?? item['title'] ?? item['label'] ?? '').toString();

      final rawEnabled = item['enabled'] ?? item['active'] ?? item['is_active'] ?? true;
      bool enabled = true;

      if (rawEnabled is bool) {
        enabled = rawEnabled;
      } else if (rawEnabled is num) {
        enabled = rawEnabled != 0;
      } else if (rawEnabled is String) {
        final v = rawEnabled.toLowerCase().trim();
        enabled = !(v == '0' || v == 'false' || v == 'off' || v == 'no' || v == 'غیرفعال');
      }

      return ServiceItem(name: name, enabled: enabled);
    }

    return ServiceItem(name: '', enabled: false);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  AppConfig config = AppConfig.empty();
  bool loading = true;
  String errorText = '';

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadConfig();
    }
  }

  Future<void> loadConfig() async {
    setState(() {
      loading = true;
      errorText = '';
    });

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse('$apiUrl?t=$now&nocache=${DateTime.now().millisecondsSinceEpoch}');

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception('API empty');
      }

      final body = utf8.decode(response.bodyBytes);
      final decoded = jsonDecode(body);

      if (decoded is! Map) {
        throw Exception('Invalid JSON');
      }

      setState(() {
        config = AppConfig.fromJson(Map<String, dynamic>.from(decoded));
        loading = false;
        errorText = '';
      });
    } catch (_) {
      setState(() {
        loading = false;
        errorText = 'اتصال با پنل برقرار نشد';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: loadConfig,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Header(title: config.title),
            const SizedBox(height: 26),

            InfoCard(
              text: config.exchangeText,
              icon: Icons.currency_exchange_rounded,
              iconColor: const Color(0xff11875d),
            ),

            const SizedBox(height: 16),

            InfoCard(
              text: config.notice,
              icon: Icons.campaign_rounded,
              iconColor: Colors.orange,
            ),

            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Center(child: CircularProgressIndicator()),
              ),

            if (errorText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Text(
                  errorText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const Padding(
              padding: EdgeInsets.fromLTRB(28, 34, 28, 16),
              child: Text(
                'خدمات',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xff222222),
                ),
              ),
            ),

            if (config.services.isEmpty && !loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'خدمتی از پنل دریافت نشد',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: GridView.builder(
                itemCount: config.services.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.04,
                ),
                itemBuilder: (context, index) {
                  return ServiceCard(service: config.services[index]);
                },
              ),
            ),

            const SizedBox(height: 34),
          ],
        ),
      ),
    );
  }
}

class Header extends StatelessWidget {
  final String title;

  const Header({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xff15c983),
            Color(0xff08784f),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(46),
          bottomRight: Radius.circular(46),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 56,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color iconColor;

  const InfoCard({
    super.key,
    required this.text,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xff1f1f1f),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  final ServiceItem service;

  const ServiceCard({
    super.key,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Icon(
            Icons.grid_view_rounded,
            color: Color(0xff11875d),
            size: 36,
          ),
          const Spacer(),
          Text(
            service.name,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Color(0xff111111),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'فعال',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xff222222),
            ),
          ),
        ],
      ),
    );
  }
}
