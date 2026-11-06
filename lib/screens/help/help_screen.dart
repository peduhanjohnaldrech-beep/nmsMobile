import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      _HelpItem('Logging In', Icons.login, 'Enter your username and password. Admin accounts will receive a 6-digit OTP code to their registered email — enter it to complete login. Mobile app sessions last 30 days.'),
      _HelpItem('Dashboard', Icons.dashboard, 'Shows summary stats: total beneficiaries, OPT assessed, pending validations, and recent activity. Quick action buttons let you jump to common tasks. Pull down to sync with the server.'),
      _HelpItem('Beneficiaries', Icons.people, 'Add, edit, and view child beneficiary records. Use the search bar to find children quickly. Tap a beneficiary to see their full profile, assessment history, and program enrollments.'),
      _HelpItem('Follow-up List', Icons.warning_amber, 'Lists all beneficiaries with Underweight (UW) or Severely Underweight (SUW) status needing immediate follow-up assessment.'),
      _HelpItem('OPT Weighing', Icons.monitor_weight, 'Record weight, height, and MUAC for children. Select a beneficiary, enter measurements, and submit. Submitted records go to the Midwife/Nutritionist for validation before appearing in reports.'),
      _HelpItem('DSP Follow-up', Icons.track_changes_rounded, 'Submit a monitoring follow-up for a DSP-enrolled child. Enter current weight and measurements and submit for validation.'),
      _HelpItem('My Submissions', Icons.assignment_turned_in, 'Track all records you submitted — beneficiary registrations and assessments. Status shown as Pending, Validated, or Returned. Returned records include a note explaining what to correct.'),
      _HelpItem('Validation Queue', Icons.verified_user, 'Midwife/Admin only — review pending beneficiary registrations and assessments submitted by BNS/BHW. Approve to validate or return with a correction note.'),
      _HelpItem('Track Records', Icons.manage_search, 'Admin/Nutritionist — view all submissions across all barangays. Filter by barangay, status, or date.'),
      _HelpItem('DSP Program', Icons.food_bank, 'Dietary Supplementation Program — enroll malnourished children, track monitoring visits and weight progress, and discharge when graduation criteria are met (2 consecutive normal validated checks).'),
      _HelpItem('MNS Program', Icons.medication, 'Micronutrient Supplementation — record Vitamin A doses (6–59 months), MNP sachets, and LNS-SQ (6–23 months) distributed to children.'),
      _HelpItem('Reports', Icons.bar_chart, 'View OPT, DSP, MNS, Outcome, Comparison, and Summary reports. Filter by year and period. Available to Admin, Nutritionist, BNS, and Midwife.'),
      _HelpItem('Activity Log', Icons.history, 'Full audit trail of all actions in the system — logins, data entries, validations, and syncs from both web and mobile.'),
      _HelpItem('User Management', Icons.manage_accounts, 'Admin only — create, edit, and deactivate accounts. Assign roles and permissions.\n\nRoles:\n• Admin — full access, web + mobile\n• Nutritionist — reports, programs, validation\n• Midwife — validation queue, assessments\n• BNS — beneficiaries, assessments, reports\n• BHW — mobile app only\n\nSet an email for each Admin to enable OTP login verification.'),
      _HelpItem('Program Manager', Icons.settings, 'Admin only — add or deactivate nutrition programs that appear in the Programs section.'),
      _HelpItem('Sync', Icons.sync, 'Syncs offline data to the server and pulls the latest records. Data entered without internet is saved locally and synced automatically when connected. Tap the sync button on the dashboard to sync manually.'),
      _HelpItem('Nutritional Status Codes', Icons.info, 'WFA (Weight-for-Age):\n• Normal — healthy weight\n• UW — Underweight\n• SUW — Severely Underweight\n• OW — Overweight\n• OB — Obese\n\nHFA (Height-for-Age):\n• Normal\n• Stunted — height Z-score < -2\n\nWFL/H (Weight-for-Length/Height):\n• Normal\n• MW — Moderately Wasted\n• SW — Severely Wasted'),
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

class _HelpCard extends StatelessWidget {
  final _HelpItem item;
  const _HelpCard({required this.item});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ExpansionTile(
      leading: Icon(item.icon, color: const Color(0xFF1565C0)),
      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Text(item.description, style: const TextStyle(height: 1.5)))],
    ),
  );
}
