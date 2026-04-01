import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/features/auth/domain/entities/auth_session.dart';
import 'package:naijapulse/features/auth/domain/usecases/get_cached_session.dart';
import 'package:naijapulse/features/news/data/datasource/remote/news_remote_datasource.dart';
import 'package:naijapulse/features/news/presentation/bloc/news_bloc.dart';
import 'package:naijapulse/features/polls/presentation/bloc/polls_bloc.dart';

class NewsSubmitPage extends StatefulWidget {
  const NewsSubmitPage({super.key});

  @override
  State<NewsSubmitPage> createState() => _NewsSubmitPageState();
}

class _NewsSubmitPageState extends State<NewsSubmitPage> {
  static const List<String> _verificationOptions = <String>[
    'unverified',
    'developing',
    'verified',
    'fact_checked',
    'opinion',
    'sponsored',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _sourceController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentUrlController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _categoryController = TextEditingController();
  String? _selectedCategory;
  String _selectedVerificationStatus = 'unverified';
  bool _publishImmediately = false;
  bool _isFeatured = false;
  bool _submitting = false;
  AuthSession? _authSession;
  bool _loadingSession = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sourceController.dispose();
    _summaryController.dispose();
    _contentUrlController.dispose();
    _imageUrlController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    AuthSession? session;
    try {
      session = await InjectionContainer.sl<GetCachedSession>()();
    } catch (_) {
      session = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _authSession = session;
      _loadingSession = false;
    });
  }

  Future<void> _promptSignIn() async {
    await context.push(AppRouter.loginPath);
    await _loadSession();
  }

  @override
  Widget build(BuildContext context) {
    final isEditorialUser = _authSession?.canManageEditorialContent ?? false;
    if (_loadingSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_authSession == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contribute Story')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Sign in to submit or publish a news article.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Guest users can browse the feed, but article submission requires a registered account.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _promptSignIn,
                    child: const Text('Log in or Sign up'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!(isEditorialUser || (_authSession?.canContributeStories ?? false))) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contribute Story')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 560),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.42),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Contribution requires admin approval',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Story submission is reserved for approved contributors and editorial staff. Visit your profile to request contribution access from the admin team.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: const [
                        _AccessChip(label: 'Submit story ideas'),
                        _AccessChip(label: 'Share source links'),
                        _AccessChip(label: 'Editorial review queue'),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push(AppRouter.profilePath),
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('Request access'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final categories = context.watch<PollsBloc>().state.categories;
    final categoryNames =
        categories
            .map((category) => category.name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (_selectedCategory == null && categoryNames.isNotEmpty) {
      _selectedCategory = categoryNames.first;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Contribute Story')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                isEditorialUser
                    ? 'Publish a source-linked article'
                    : 'Submit a news story',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                isEditorialUser
                    ? 'Create a draft or publish an article that opens the source website in-app.'
                    : 'Stories are submitted for editorial review before they appear in the feed.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.length < 5) {
                    return 'Enter at least 5 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              if (isEditorialUser) ...[
                TextFormField(
                  controller: _sourceController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Source name'),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.length < 2) {
                      return 'Enter a valid source name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
              ],
              if (categoryNames.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  items: categoryNames
                      .map(
                        (name) => DropdownMenuItem<String>(
                          value: name,
                          child: Text(name),
                        ),
                      )
                      .toList(),
                  decoration: const InputDecoration(labelText: 'Category'),
                  onChanged: (value) =>
                      setState(() => _selectedCategory = value),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Choose a category.';
                    }
                    return null;
                  },
                )
              else
                TextFormField(
                  controller: _categoryController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Category'),
                  validator: (value) {
                    if ((value ?? '').trim().length < 2) {
                      return 'Enter a valid category.';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _summaryController,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Summary',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contentUrlController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: isEditorialUser
                      ? 'Source URL'
                      : 'Article URL (optional)',
                ),
                keyboardType: TextInputType.url,
                validator: isEditorialUser
                    ? (value) {
                        final text = (value ?? '').trim();
                        if (!text.startsWith('http://') &&
                            !text.startsWith('https://')) {
                          return 'Enter a valid source URL.';
                        }
                        return null;
                      }
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _imageUrlController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Image URL (optional)',
                ),
                keyboardType: TextInputType.url,
              ),
              if (isEditorialUser) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedVerificationStatus,
                  items: _verificationOptions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(_verificationLabel(value)),
                        ),
                      )
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Verification status',
                  ),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedVerificationStatus = value);
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Publish immediately'),
                  subtitle: const Text(
                    'Turn this off to save the article as a draft.',
                  ),
                  value: _publishImmediately,
                  onChanged: (value) =>
                      setState(() => _publishImmediately = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Feature this article'),
                  subtitle: const Text(
                    'Featured articles are eligible for more prominent placement.',
                  ),
                  value: _isFeatured,
                  onChanged: (value) => setState(() => _isFeatured = value),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _submitting
                      ? 'Saving...'
                      : isEditorialUser
                      ? (_publishImmediately ? 'Publish Article' : 'Save Draft')
                      : 'Submit Story',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_authSession == null) {
      await _promptSignIn();
      return;
    }
    if (_submitting) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _submitting = true);
    final remote = InjectionContainer.sl<NewsRemoteDataSource>();
    try {
      if (_authSession?.canManageEditorialContent ?? false) {
        await remote.createAdminArticle(
          title: _titleController.text.trim(),
          source: _sourceController.text.trim(),
          category: (_selectedCategory ?? '').trim().isNotEmpty
              ? (_selectedCategory ?? '').trim()
              : _categoryController.text.trim(),
          sourceUrl: _contentUrlController.text.trim(),
          summary: _summaryController.text.trim(),
          imageUrl: _imageUrlController.text.trim(),
          status: _publishImmediately ? 'published' : 'draft',
          verificationStatus: _selectedVerificationStatus,
          isFeatured: _isFeatured,
        );
      } else {
        await remote.createUserArticle(
          title: _titleController.text.trim(),
          category: (_selectedCategory ?? '').trim().isNotEmpty
              ? (_selectedCategory ?? '').trim()
              : _categoryController.text.trim(),
          summary: _summaryController.text.trim(),
          contentUrl: _contentUrlController.text.trim(),
          imageUrl: _imageUrlController.text.trim(),
        );
      }
      if (!mounted) {
        return;
      }
      context.read<NewsBloc>().add(const LoadNewsRequested());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _authSession?.canManageEditorialContent ?? false
                ? (_publishImmediately
                      ? 'Article published successfully.'
                      : 'Draft saved successfully.')
                : 'Story submitted successfully.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _verificationLabel(String value) {
    switch (value) {
      case 'developing':
        return 'Developing';
      case 'verified':
        return 'Verified';
      case 'fact_checked':
        return 'Fact-checked';
      case 'opinion':
        return 'Opinion';
      case 'sponsored':
        return 'Sponsored';
      default:
        return 'Unverified';
    }
  }
}

class _AccessChip extends StatelessWidget {
  const _AccessChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
