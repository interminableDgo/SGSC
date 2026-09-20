import 'package:flutter/material.dart';

import '../core/theme.dart';

class ExecutiveCard extends StatelessWidget {
  final String title;
  final String? source;
  final Widget child;
  const ExecutiveCard({
    super.key,
    required this.title,
    required this.child,
    this.source,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F1B2A33),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (source != null)
              IconButton(
                tooltip: 'Cómo se calcula',
                icon: const Icon(Icons.info_outline, size: 18, color: muted),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(title),
                    content: Text(source!),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Entendido'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class Notice extends StatelessWidget {
  final String message;
  final bool error;
  const Notice(this.message, {super.key, this.error = false});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFF8E7E5) : blueTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: error ? const Color(0xFFC6483F) : ink,
        ),
      ),
    ),
  );
}

class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const LabeledField(this.label, this.child, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class PageHeading extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const PageHeading(this.title, {super.key, required this.onBack});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Volver',
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ],
    ),
  );
}
