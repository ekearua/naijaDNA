import 'package:url_launcher/url_launcher.dart';

Future<bool> openExternalLink(String url, {String target = '_blank'}) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> openInAppBrowserLink(
  String url, {
  String target = '_blank',
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  return launchUrl(uri, mode: LaunchMode.inAppBrowserView);
}
