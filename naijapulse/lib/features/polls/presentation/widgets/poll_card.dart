import 'package:flutter/material.dart';
import 'package:naijapulse/features/polls/domain/entities/poll.dart';

class PollCard extends StatelessWidget {
  final Poll poll;
  final bool isSubmitting;
  final ValueChanged<String> onVote;

  const PollCard({
    super.key,
    required this.poll,
    required this.onVote,
    this.isSubmitting = false,
  });

  @override
  Widget build(BuildContext context) {
    final canVote = !poll.isClosed && !poll.hasVoted && !isSubmitting;
    final totalVotes = poll.totalVotes == 0 ? 1 : poll.totalVotes;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(poll.question, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              poll.isClosed
                  ? 'Poll closed'
                  : 'Ends ${_formatEndsAt(poll.endsAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ...poll.options.map((option) {
              final percent = ((option.votes / totalVotes) * 100).round();
              final isSelected = poll.selectedOptionId == option.id;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: canVote
                    ? OutlinedButton(
                        onPressed: () => onVote(option.id),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          alignment: Alignment.centerLeft,
                        ),
                        child: Text(option.label),
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(option.label)),
                            Text('${option.votes} votes'),
                            const SizedBox(width: 8),
                            Text('$percent%'),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.check_circle,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ],
                        ),
                      ),
              );
            }),
            if (isSubmitting)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  String _formatEndsAt(DateTime endsAt) {
    return '${endsAt.day.toString().padLeft(2, '0')}/'
        '${endsAt.month.toString().padLeft(2, '0')}/'
        '${endsAt.year}';
  }
}
