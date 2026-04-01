String plainTextExcerpt(String? raw) {
  final input = (raw ?? '').trim();
  if (input.isEmpty) {
    return '';
  }

  final withoutTags = input
      .replaceAll(
        RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false),
        ' ',
      )
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
}
