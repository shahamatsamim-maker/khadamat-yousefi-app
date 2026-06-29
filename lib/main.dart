import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const apiUrl = 'https://app.khanger1234.com/api/yusufi-config';

void main() {
  runApp(const YusufiApp());
}

class YusufiApp extends StatelessWidget {
  const YusufiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'خدمات یوسفی',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff168a5b)),
        scaffoldBackgroundColor: const Color(0xfff4f7fb),
      ),
      home: const HomePage(),
    );
  }
}

class AppData {
  final String title;
  final String notice;
  final String exchange;
  final String whatsapp;
  final String imo;
  final List<ServiceData> services;

  AppData({
    required this.title,
    required this.notice,
    required this.exchange,
    required this.whatsapp,
    required this.imo,
    required this.services,
  });

  factory AppData.def() {
    return AppData(
      title: 'خدمات یوسفی',
      notice: 'به خدمات یوسفی خوش آمدید',
      exchange: 'یک میلیون تومان مساوی است با ۴۰۰ افغانی',
      whatsapp: '09331571054',
      imo: '09051317904',
      services: const [
        ServiceData('حواله ایران به افغانستان', true),
        ServiceData('حواله افغانستان به ایران', true),
        ServiceData('شارژ ایران و افغانستان', true),
        ServiceData('کارت به کارت ایران', true),
        ServiceData('خدمات بازی و پابجی', true),
        ServiceData('VPN و فیلترشکن', true),
      ],
    );
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    final d = AppData.def();
    final m = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json['config'] is Map<String, dynamic>
            ? json['config'] as Map<String, dynamic>
            : json;

    return AppData(
      title: text(m, ['app_title', 'title', 'name'], d.title),
      notice: text(m, ['notice', 'message', 'home_notice'], d.notice),
      exchange: text(
          m,
          ['exchange_text', 'exchange', 'rate_text', 'exchange_rate'],
          d.exchange),
      whatsapp: text(
          m, ['whatsapp', 'whatsapp_number', 'support_whatsapp'], d.whatsapp),
      imo: text(m, ['imo', 'imo_number', 'support_imo'], d.imo),
      services: readServices(m['services'], d.services),
    );
  }

  static String text(
      Map<String, dynamic> m, List<String> keys, String fallback) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().trim().isNotEmpty)
        return v.toString().trim();
    }
    return fallback;
  }

  static List<ServiceData> readServices(
      dynamic value, List<ServiceData> fallback) {
    final out = <ServiceData>[];

    if (value is List) {
      for (final item in value) {
        if (item is Map) {
          final name =
              (item['name'] ?? item['title'] ?? item['label'] ?? '').toString();
          final enabled = item['enabled'] == false || item['active'] == false
              ? false
              : true;
          if (name.trim().isNotEmpty)
            out.add(ServiceData(name.trim(), enabled));
        } else {
          final name = item.toString().trim();
          if (name.isNotEmpty) out.add(ServiceData(name, true));
        }
      }
    }

    if (value is Map) {
      value.forEach((key, val) {
        if (val is Map) {
          final name = (val['name'] ?? val['title'] ?? key).toString();
          final enabled =
              val['enabled'] == false || val['active'] == false ? false : true;
          out.add(ServiceData(name, enabled));
        }
      });
    }

    return out.isEmpty ? fallback : out;
  }
}

class ServiceData {
  final String name;
  final bool enabled;
  const ServiceData(this.name, this.enabled);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AppData data = AppData.def();
  bool loading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final res = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 12));
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        data = AppData.fromJson(decoded);
      }
    } catch (_) {
      error = 'اتصال به پنل برقرار نشد؛ اطلاعات پیش‌فرض نمایش داده شد.';
    }

    setState(() {
      loading = false;
    });
  }

  String phoneForWhatsApp(String p) {
    var n = p.replaceAll(RegExp(r'[^0-9]'), '');
    if (n.startsWith('0')) n = '98${n.substring(1)}';
    return n;
  }

  Future<void> openWhatsApp(String service) async {
    final phone = phoneForWhatsApp(data.whatsapp);
    final msg = Uri.encodeComponent('سلام، برای $service درخواست دارم.');
    final uri = Uri.parse('https://wa.me/$phone?text=$msg');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void openService(ServiceData s) {
    if (!s.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('این خدمت فعلاً غیرفعال است')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(26)),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Text('واتساپ: ${data.whatsapp}'),
                const SizedBox(height: 6),
                Text('ایمو: ${data.imo}'),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => openWhatsApp(s.name),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff168a5b),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                    ),
                    child: const Text('ارسال درخواست در واتساپ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: loadData,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 55, 18, 28),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xff106d49), Color(0xff1fb878)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(34),
                    bottomRight: Radius.circular(34),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                        color: Colors.white, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        data.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (loading)
                      const CircularProgressIndicator(color: Colors.white),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (error.isNotEmpty)
                      card(Text(error,
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold))),
                    card(Row(
                      children: [
                        const Icon(Icons.currency_exchange,
                            color: Color(0xff168a5b)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(data.exchange,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900))),
                      ],
                    )),
                    card(Row(
                      children: [
                        const Icon(Icons.campaign, color: Colors.orange),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(data.notice,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),
                      ],
                    )),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('خدمات',
                          style: TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: data.services.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.15,
                      ),
                      itemBuilder: (_, i) {
                        final s = data.services[i];
                        return GestureDetector(
                          onTap: () => openService(s),
                          child: Opacity(
                            opacity: s.enabled ? 1 : .45,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: box(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.apps_rounded,
                                      color: Color(0xff168a5b), size: 36),
                                  const Spacer(),
                                  Text(s.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15)),
                                  const SizedBox(height: 6),
                                  Text(s.enabled ? 'فعال' : 'غیرفعال'),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget card(Widget child) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: box(),
      child: child,
    );
  }

  BoxDecoration box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 16,
            offset: const Offset(0, 8))
      ],
    );
  }
}
