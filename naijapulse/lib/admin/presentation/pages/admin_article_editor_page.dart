import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/admin/data/datasource/admin_remote_datasource.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';

class AdminArticleEditorPage extends StatefulWidget {
  const AdminArticleEditorPage({this.articleId, super.key});

  final String? articleId;

  @override
  State<AdminArticleEditorPage> createState() => _AdminArticleEditorPageState();
}

class _AdminArticleEditorPageState extends State<AdminArticleEditorPage> {
  static const List<String> _verificationOptions = <String>[
    'unverified',
    'developing',
    'verified',
    'fact_checked',
    'opinion',
    'sponsored',
  ];

  static const List<String> _createStatusOptions = <String>[
    'draft',
    'submitted',
    'approved',
    'published',
  ];

  final AdminRemoteDataSource _remote =
      InjectionContainer.sl<AdminRemoteDataSource>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _sourceUrlController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _reviewNotesController = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  String? _errorMessage;
  String _verificationStatus = 'unverified';
  String _creationStatus = 'draft';
  bool _isFeatured = false;

  bool get _isEditing => widget.articleId?.trim().isNotEmpty ?? false;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadArticle();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sourceController.dispose();
    _categoryController.dispose();
    _summaryController.dispose();
    _sourceUrlController.dispose();
    _imageUrlController.dispose();
    _reviewNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadArticle() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final detail = await _remote.fetchAdminArticleDetail(widget.articleId!);
      final article = detail.article;
      if (!mounted) {
        return;
      }
      setState(() {
        _titleController.text = article.title;
        _sourceController.text = article.source;
        _categoryController.text = article.category;
        _summaryController.text = article.summary ?? '';
        _sourceUrlController.text = article.articleUrl ?? '';
        _imageUrlController.text = article.imageUrl ?? '';
        _reviewNotesController.text = article.reviewNotes ?? '';
        _verificationStatus = article.verificationStatus;
        _creationStatus = _createStatusOptions.contains(article.status)
            ? article.status
            : _creationStatus;
        _isFeatured = article.isFeatured;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = mapFailure(error).message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final article = _isEditing
          ? await _remote.updateAdminArticle(
              articleId: widget.articleId!,
              title: _titleController.text,
              source: _sourceController.text,
              category: _categoryController.text,
              summary: _summaryController.text,
              sourceUrl: _sourceUrlController.text,
              imageUrl: _imageUrlController.text,
              verificationStatus: _verificationStatus,
              isFeatured: _isFeatured,
              reviewNotes: _reviewNotesController.text,
            )
          : await _remote.createAdminArticle(
              title: _titleController.text,
              source: _sourceController.text,
              category: _categoryController.text,
              summary: _summaryController.text,
              sourceUrl: _sourceUrlController.text,
              imageUrl: _imageUrlController.text,
              status: _creationStatus,
              verificationStatus: _verificationStatus,
              isFeatured: _isFeatured,
              reviewNotes: _reviewNotesController.text,
            );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Article changes saved.'
                : 'Article created successfully.',
          ),
        ),
      );
      context.go(AppRouter.adminArticleDetailPath(article.id));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _EditorStateCard(
        title: 'Could not load this article',
        message: _errorMessage!,
        actionLabel: 'Back to queue',
        onPressed: () => context.go(AppRouter.adminArticlesPath),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () => context.go(AppRouter.adminArticlesPath),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to queue'),
            ),
            const Spacer(),
            if (_isEditing)
              OutlinedButton.icon(
                onPressed: () => context.go(
                  AppRouter.adminArticleDetailPath(widget.articleId!),
                ),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Open detail'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing ? 'Edit Article' : 'Create Article',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isEditing
                        ? 'Update source-linked article metadata, trust labels, and editorial notes.'
                        : 'Create a newsroom article that opens the publisher source inside the reader.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF6E675C),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isEditing ? 'Save changes' : 'Create article'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2DBCF)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _LabeledField(
                    label: 'Title',
                    child: TextFormField(
                      controller: _titleController,
                      decoration: _inputDecoration('Headline for the article'),
                      validator: (value) => _minLength(value, min: 5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _LabeledField(
                          label: 'Source',
                          child: TextFormField(
                            controller: _sourceController,
                            decoration: _inputDecoration('Premium Times'),
                            validator: (value) => _minLength(value, min: 2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _LabeledField(
                          label: 'Category',
                          child: TextFormField(
                            controller: _categoryController,
                            decoration: _inputDecoration('Politics'),
                            validator: (value) => _minLength(value, min: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _LabeledField(
                    label: 'Summary',
                    child: TextFormField(
                      controller: _summaryController,
                      maxLines: 5,
                      decoration: _inputDecoration(
                        'Short summary shown in feeds and editorial review.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _LabeledField(
                          label: 'Source URL',
                          child: TextFormField(
                            controller: _sourceUrlController,
                            keyboardType: TextInputType.url,
                            decoration: _inputDecoration(
                              'https://publisher.com/story',
                            ),
                            validator: _validateUrl,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _LabeledField(
                          label: 'Image URL',
                          child: TextFormField(
                            controller: _imageUrlController,
                            keyboardType: TextInputType.url,
                            decoration: _inputDecoration(
                              'https://publisher.com/image.jpg',
                            ),
                            validator: (value) {
                              final input = (value ?? '').trim();
                              if (input.isEmpty) {
                                return null;
                              }
                              return _validateUrl(input);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _LabeledField(
                          label: 'Verification status',
                          child: DropdownButtonFormField<String>(
                            initialValue: _verificationStatus,
                            decoration: _dropdownDecoration(),
                            items: _verificationOptions
                                .map(
                                  (value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(_prettyLabel(value)),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() => _verificationStatus = value);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _LabeledField(
                          label: _isEditing ? 'Workflow status' : 'Create as',
                          child: DropdownButtonFormField<String>(
                            initialValue: _creationStatus,
                            decoration: _dropdownDecoration(),
                            items: _createStatusOptions
                                .map(
                                  (value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(_prettyLabel(value)),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _isEditing
                                ? null
                                : (value) {
                                    if (value == null) {
                                      return;
                                    }
                                    setState(() => _creationStatus = value);
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _isFeatured,
                    onChanged: (value) => setState(() => _isFeatured = value),
                    title: const Text('Feature this article'),
                    subtitle: const Text(
                      'Featured stories are eligible for more prominent placement in the newsroom outputs.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _LabeledField(
                    label: 'Editorial notes',
                    child: TextFormField(
                      controller: _reviewNotesController,
                      maxLines: 4,
                      decoration: _inputDecoration(
                        'Context for reviewers, verification notes, or publication instructions.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _minLength(String? value, {required int min}) {
    final input = (value ?? '').trim();
    if (input.length < min) {
      return 'Enter at least $min characters.';
    }
    return null;
  }

  String? _validateUrl(String? value) {
    final input = (value ?? '').trim();
    if (!input.startsWith('http://') && !input.startsWith('https://')) {
      return 'Enter a valid URL starting with http:// or https://.';
    }
    return null;
  }

  String _prettyLabel(String value) => value
      .split('_')
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  InputDecoration _inputDecoration(String hintText) => InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: const Color(0xFFFFFCF8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFD8D3C7)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFD8D3C7)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF0F6B4B), width: 1.5),
    ),
  );

  InputDecoration _dropdownDecoration() => InputDecoration(
    filled: true,
    fillColor: const Color(0xFFFFFCF8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFD8D3C7)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFD8D3C7)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF0F6B4B), width: 1.5),
    ),
  );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D1B18),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _EditorStateCard extends StatelessWidget {
  const _EditorStateCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2DBCF)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6E675C),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: onPressed, child: Text(actionLabel)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
