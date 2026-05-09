import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../hydration/data/hydration_api.dart';
import '../../hydration/presentation/hydration_page.dart';

/// Thin bridge used by the home-screen dashboard card.
/// Creates its own [ApiClient] from [AppConfig] so [home_page.dart] stays const.
class HydrationDetailPage extends StatefulWidget {
  const HydrationDetailPage({super.key});

  @override
  State<HydrationDetailPage> createState() => _HydrationDetailPageState();
}

class _HydrationDetailPageState extends State<HydrationDetailPage> {
  late final ApiClient _apiClient;
  late final HydrationApi _api;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(
      baseUrl: AppConfig.apiBaseUrl,
      userId: AppConfig.userId,
    );
    _api = HydrationApi(_apiClient);
  }

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HydrationPage(api: _api);
  }
}
