import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      _HelpItem('Dashboard', Icons.dashboard, 'View summary statistics, recent beneficiaries, quick actions, and sync status.'),
      _HelpItem('Beneficiaries', Icons.people, 'Add, edit, view and manage beneficiary records. Use the search bar to find specific children. Tap a beneficiary to see their full profile and assessment history.'),
      _HelpItem('Follow-up List', Icons.warning_amber, 'Lists all beneficiaries with Underweight (UW) or Severely Underweight (SUW) status needing immediate follow-up.'),
      _HelpItem('Trash', Icons.delete, 'Soft-deleted beneficiaries are stored here. You can restore them if deleted by mistake.'),
      _HelpItem('Assessments', Icons.monitor_weight, 'Record individual or batch nutritional assessments. Weight, height, and MUAC are used to compute Z-scores automatically.'),
      _HelpItem('OPT Program', Icons.scale, 'Operation Timbang — view nutritional status results by year and period (January or July).'),
      _HelpItem('DSP Program', Icons.food_bank, 'Dietary Supplementation Program — enroll malnourished children, track intervention type, update progress, and discharge.'),
      _HelpItem('MNS Program', Icons.medication, 'Micronutrient Supplementation — record Vitamin A doses, MNP sachets, and LNS-SQ given to children.'),
      _HelpItem('Dispensing', Icons.local_pharmacy, 'Record supplements and food items dispensed to beneficiaries under various programs.'),
      _HelpItem('Reports', Icons.bar_chart, 'View OPT, DSP, MNS, Outcome, Comparison, and Distribution reports. Filter by year and period.'),
      _HelpItem('Activity Log', Icons.history, 'See a history of all actions performed by users in the system.'),
      _HelpItem('User Management', Icons.manage_accounts, 'Admin only — create, edit, and deactivate user accounts. Assign roles: Admin, Nutritionist, BHW, Encoder.'),
      _HelpItem('Sync', Icons.sync, 'Tap the sync button on the dashboard to push offline records to the server and pull the latest data. Requires internet connection.'),
      _HelpItem('Nutritional Status Codes', Icons.info, 'Normal = healthy weight\nUW = Underweight\nSUW = Severely Underweight\nOW = Overweight\nOB = Obese'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Help'), backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, i) => _HelpCard(item: items[i]),
      ),
    );
  }
}

class _HelpItem {
  final String title;
  final IconData icon;
  final String description;
  const _HelpItem(this.title, this.icon, this.description);
}

class _HelpCard extends StatefulWidget {
  final _HelpItem item;
  const _HelpCard({required this.item, super.key});
  @override State<_HelpCard> createState() => _HelpCardState();
}

class _HelpCardState extends State<_HelpCard> {
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ExpansionTile(
      leading: Icon(widget.item.icon, color: const Color(0xFF1565C0)),
      title: Text(widget.item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Text(widget.item.description, style: const TextStyle(height: 1.5)))],
    ),
  );
}
