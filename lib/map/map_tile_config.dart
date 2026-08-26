import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_maplibre/flutter_map_maplibre.dart';
import 'package:maplibre/maplibre.dart' as ml;

import '../desktop/external_url_launcher.dart';
import '../plan/pilgrimage_models.dart';

const openFreeMapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';
const openStreetMapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const mapUserAgentPackageName = 'app.miriago.miriago';

class OpenFreeMapStyleOption {
  const OpenFreeMapStyleOption({
    required this.style,
    required this.label,
    required this.description,
    required this.styleUrl,
  });

  final OpenFreeMapStyle style;
  final String label;
  final String description;
  final String styleUrl;
}

class MapTileProviderOption {
  const MapTileProviderOption({
    required this.provider,
    required this.label,
    required this.description,
  });

  final MapTileProvider provider;
  final String label;
  final String description;
}

const openFreeMapStyleOptions = [
  OpenFreeMapStyleOption(
    style: OpenFreeMapStyle.liberty,
    label: 'Liberty',
    description: '默认样式，信息密度较高。',
    styleUrl: 'https://tiles.openfreemap.org/styles/liberty',
  ),
  OpenFreeMapStyleOption(
    style: OpenFreeMapStyle.bright,
    label: 'Bright',
    description: '明亮标准样式。',
    styleUrl: 'https://tiles.openfreemap.org/styles/bright',
  ),
  OpenFreeMapStyleOption(
    style: OpenFreeMapStyle.positron,
    label: 'Positron',
    description: '浅色低干扰样式。',
    styleUrl: 'https://tiles.openfreemap.org/styles/positron',
  ),
  OpenFreeMapStyleOption(
    style: OpenFreeMapStyle.dark,
    label: 'Dark',
    description: '深色地图样式。',
    styleUrl: 'https://tiles.openfreemap.org/styles/dark',
  ),
  OpenFreeMapStyleOption(
    style: OpenFreeMapStyle.fiord,
    label: 'Fiord',
    description: '柔和地形风格。',
    styleUrl: 'https://tiles.openfreemap.org/styles/fiord',
  ),
];

const mapTileProviderOptions = [
  MapTileProviderOption(
    provider: MapTileProvider.openFreeMap,
    label: 'OpenFreeMap',
    description: '默认地图，使用 MapLibre style。',
  ),
  MapTileProviderOption(
    provider: MapTileProvider.openStreetMap,
    label: 'OpenStreetMap',
    description: '使用 OpenStreetMap 标准 XYZ 瓦片。',
  ),
  MapTileProviderOption(
    provider: MapTileProvider.customXyz,
    label: '自定义 XYZ',
    description: '使用包含 {z}/{x}/{y} 的栅格瓦片 URL。',
  ),
  MapTileProviderOption(
    provider: MapTileProvider.customMapLibreStyle,
    label: '自定义 MapLibre',
    description: '使用自定义 MapLibre style URL。',
  ),
];

OpenFreeMapStyleOption openFreeMapStyleOption(OpenFreeMapStyle style) {
  return openFreeMapStyleOptions.firstWhere(
    (option) => option.style == style,
    orElse: () => openFreeMapStyleOptions.first,
  );
}

MapTileProviderOption mapTileProviderOption(MapTileProvider provider) {
  return mapTileProviderOptions.firstWhere(
    (option) => option.provider == provider,
    orElse: () => mapTileProviderOptions.first,
  );
}

bool mapProviderUsesMapLibre(MapTileProvider provider) {
  return provider == MapTileProvider.openFreeMap ||
      provider == MapTileProvider.customMapLibreStyle;
}

String mapLibreStyleUrl(AppSettings settings) {
  if (settings.mapTileProvider == MapTileProvider.customMapLibreStyle) {
    final custom = settings.customMapLibreStyleUrl.trim();
    if (_isHttpUrl(custom)) {
      return custom;
    }
  }
  return openFreeMapStyleOption(settings.openFreeMapStyle).styleUrl;
}

String xyzTileUrl(AppSettings settings) {
  if (settings.mapTileProvider == MapTileProvider.customXyz) {
    final custom = settings.customXyzTileUrl.trim();
    if (isValidXyzTileUrl(custom)) {
      return custom;
    }
  }
  return openStreetMapTileUrl;
}

Widget configuredMapTileLayer(AppSettings settings) {
  final layerKey = ValueKey(mapTileConfigSignature(settings));
  if (mapProviderUsesMapLibre(settings.mapTileProvider) &&
      !_isFlutterWidgetTest) {
    return _OfflineAwareMapLibreLayer(
      key: layerKey,
      initStyle: mapLibreStyleUrl(settings),
    );
  }
  return configuredRasterTileLayer(settings, key: layerKey);
}

class _OfflineAwareMapLibreLayer extends StatefulWidget {
  const _OfflineAwareMapLibreLayer({required this.initStyle, super.key});

  final String initStyle;

  @override
  State<_OfflineAwareMapLibreLayer> createState() =>
      _OfflineAwareMapLibreLayerState();
}

class _OfflineAwareMapLibreLayerState
    extends State<_OfflineAwareMapLibreLayer> {
  static const _styleLoadTimeout = Duration(seconds: 8);

  Timer? _styleLoadTimer;
  bool _styleLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _styleLoadTimer = Timer(_styleLoadTimeout, () {
      if (mounted) {
        setState(() {
          _styleLoadFailed = true;
        });
      }
    });
  }

  void _handleMapEvent(ml.MapEvent event) {
    if (event is! ml.MapEventStyleLoaded) {
      return;
    }
    _styleLoadTimer?.cancel();
    if (mounted && _styleLoadFailed) {
      setState(() {
        _styleLoadFailed = false;
      });
    }
  }

  @override
  void dispose() {
    _styleLoadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapLibreLayer(initStyle: widget.initStyle, onEvent: _handleMapEvent),
        if (_styleLoadFailed)
          const Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _OfflineMapNotice(),
          ),
      ],
    );
  }
}

class _OfflineMapNotice extends StatelessWidget {
  const _OfflineMapNotice();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('底图暂不可用，请检查网络或地图源设置。应用记录和已缓存图片仍可使用。')),
            ],
          ),
        ),
      ),
    );
  }
}

TileLayer configuredRasterTileLayer(AppSettings settings, {Key? key}) {
  return TileLayer(
    key: key,
    urlTemplate: xyzTileUrl(settings),
    userAgentPackageName: mapUserAgentPackageName,
  );
}

String mapTileConfigSignature(AppSettings settings) {
  return [
    settings.mapTileProvider.name,
    settings.openFreeMapStyle.name,
    settings.customXyzTileUrl.trim(),
    settings.customMapLibreStyleUrl.trim(),
  ].join('|');
}

RichAttributionWidget configuredMapAttribution(AppSettings settings) {
  final provider = settings.mapTileProvider;
  if (mapProviderUsesMapLibre(provider)) {
    return RichAttributionWidget(
      attributions: [
        TextSourceAttribution(
          'OpenFreeMap / OpenMapTiles contributors',
          onTap: () {
            launchExternalUrl(Uri.parse('https://openfreemap.org/'));
          },
        ),
      ],
    );
  }
  return RichAttributionWidget(
    attributions: [
      TextSourceAttribution(
        'OpenStreetMap contributors',
        onTap: () {
          launchExternalUrl(
            Uri.parse('https://www.openstreetmap.org/copyright'),
          );
        },
      ),
    ],
  );
}

String? validateMapTileSettings(AppSettings settings) {
  return switch (settings.mapTileProvider) {
    MapTileProvider.customXyz =>
      isValidXyzTileUrl(settings.customXyzTileUrl.trim())
          ? null
          : '自定义 XYZ URL 需要包含 {z}、{x}、{y}，并使用 http/https。',
    MapTileProvider.customMapLibreStyle =>
      _isHttpUrl(settings.customMapLibreStyleUrl.trim())
          ? null
          : '自定义 MapLibre style URL 需要使用 http/https。',
    _ => null,
  };
}

bool isValidXyzTileUrl(String value) {
  return _isHttpUrl(value) &&
      value.contains('{z}') &&
      value.contains('{x}') &&
      value.contains('{y}');
}

bool _isHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

bool get _isFlutterWidgetTest {
  return WidgetsBinding.instance.runtimeType.toString().contains('TestWidgets');
}
