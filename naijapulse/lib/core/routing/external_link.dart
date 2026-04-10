import 'external_link_stub.dart'
    if (dart.library.html) 'external_link_web.dart'
    as external_link;

Future<bool> openExternalLink(String url, {String target = '_blank'}) {
  return external_link.openExternalLink(url, target: target);
}

Future<bool> openInAppBrowserLink(String url, {String target = '_blank'}) {
  return external_link.openInAppBrowserLink(url, target: target);
}
