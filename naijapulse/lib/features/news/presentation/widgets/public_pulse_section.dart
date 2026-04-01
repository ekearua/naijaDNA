import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:naijapulse/features/polls/domain/entities/poll.dart';
import 'package:naijapulse/features/polls/presentation/bloc/polls_bloc.dart';

class PublicPulseSection extends StatelessWidget {
  const PublicPulseSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PollsBloc, PollsState>(
      builder: (context, pollsState) {
        if (pollsState.status == PollsStatus.loading &&
            pollsState.polls.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (pollsState.polls.isEmpty) {
          // Parent sections now hide poll widgets when backend returns no data.
          return const SizedBox.shrink();
        }

        final poll = pollsState.polls.first;
        return PublicPulseCard(
          poll: poll,
          isSubmitting: pollsState.status == PollsStatus.submitting,
          onVote: (optionId) {
            context.read<PollsBloc>().add(
              VotePollRequested(pollId: poll.id, optionId: optionId),
            );
          },
        );
      },
    );
  }
}

class PublicPulseCard extends StatefulWidget {
  const PublicPulseCard({
    required this.poll,
    required this.isSubmitting,
    required this.onVote,
    super.key,
  });

  final Poll poll;
  final bool isSubmitting;
  final ValueChanged<String> onVote;

  @override
  State<PublicPulseCard> createState() => _PublicPulseCardState();
}

class _PublicPulseCardState extends State<PublicPulseCard> {
  String? _selectedOptionId;

  @override
  void initState() {
    super.initState();
    _selectedOptionId =
        widget.poll.selectedOptionId ??
        (widget.poll.options.isNotEmpty ? widget.poll.options.first.id : null);
  }

  @override
  void didUpdateWidget(covariant PublicPulseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poll.id != widget.poll.id) {
      _selectedOptionId =
          widget.poll.selectedOptionId ??
          (widget.poll.options.isNotEmpty
              ? widget.poll.options.first.id
              : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canVote =
        !widget.poll.isClosed && !widget.poll.hasVoted && !widget.isSubmitting;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.poll.question,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.poll.options.map((option) {
                      final isSelected = option.id == _selectedOptionId;
                      return ChoiceChip(
                        label: Text(option.label),
                        selected: isSelected,
                        onSelected: canVote
                            ? (_) =>
                                  setState(() => _selectedOptionId = option.id)
                            : null,
                        showCheckmark: false,
                        selectedColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.16),
                        side: BorderSide(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 92,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.poll_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 10,
                        child: Icon(Icons.person, size: 12),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.poll.hasVoted
                              ? 'Thanks for voting - ${widget.poll.totalVotes} votes'
                              : '@naijapulse - ${widget.poll.totalVotes} participants',
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 128,
                  child: ElevatedButton(
                    onPressed: canVote && _selectedOptionId != null
                        ? () => widget.onVote(_selectedOptionId!)
                        : null,
                    child: widget.isSubmitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.poll.hasVoted ? 'Voted' : 'Vote'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
