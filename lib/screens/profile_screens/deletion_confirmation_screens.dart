import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF8FAF7);
  static const Color primaryGreen = Color(0xFF1D3305);
  static const Color activeGreen = Color(0xFFA6D679);
  static const Color warningRed = Color(0xFFBC1C1C);
  static const Color criticalBadge = Color(0xFFFDE8E8);
  static const Color textBody = Color(0xFF555555);
  static const Color pinkWarning = Color(0xFFFFE3E3);
  static const Color cardGrey = Color(0xFFF0F2EF);
}

class AccountDeletionFlow extends StatefulWidget {
  const AccountDeletionFlow({super.key});

  @override
  State<AccountDeletionFlow> createState() => _AccountDeletionFlowState();
}

class _AccountDeletionFlowState extends State<AccountDeletionFlow> {
  final PageController _pageController = PageController();

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Hide leading/title on the Success screen
        leading: _pageController.hasClients && _pageController.page == 2
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1D3305)),
                onPressed: () {
                  if (_pageController.page == 0) {
                    // Exit
                  } else {
                    _previousPage();
                  }
                },
              ),
        title: _pageController.hasClients && _pageController.page == 2
            ? null
            : Text(
                _pageController.hasClients && _pageController.page == 1
                    ? 'Account Settings'
                    : 'Account Security',
                style: const TextStyle(
                    color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
              ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          StepOneScreen(onProceed: _nextPage),
          StepTwoScreen(onBack: _previousPage, onDelete: _nextPage),
          const SuccessDeletionScreen(),
        ],
      ),
    );
  }
}

// --- SCREEN 01 ---
class StepOneScreen extends StatelessWidget {
  final VoidCallback onProceed;
  const StepOneScreen({super.key, required this.onProceed});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProgressBar(step: 1),
          const SizedBox(height: 32),
          const CriticalBadge(),
          const SizedBox(height: 24),
          const Text("Before you go,\nlet's talk about\nyour harvest.",
              style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1)),
          const SizedBox(height: 24),
          const Text(
              "Deleting your account is permanent. All stewardship data curated over the seasons will be irrecoverably removed from the Verdant Harvest ecosystem.",
              style: TextStyle(color: AppColors.textBody, fontSize: 16, height: 1.5)),
          const SizedBox(height: 32),
          const SecurityDataCard(
              icon: Icons.history_edu,
              title: "Historical Records",
              description: "Five years of planting cycles, soil amendment logs, and harvest yields will be purged. Your digital legacy as a land steward cannot be restored."),
          const SizedBox(height: 16),
          const SecurityDataCard(
              icon: Icons.visibility_outlined,
              title: "Scouting Data",
              description: "Pest monitoring, moisture readings, and satellite imagery overlays will be disconnected and deleted.",
              color: Color(0xFFF1F4F1)),
          const SizedBox(height: 16),
          const SecurityDataCard(
              icon: Icons.admin_panel_settings_outlined,
              title: "Profile Assets",
              description: "Personalized alerts, trusted collaborator permissions, and your professional farmer identity settings.",
              color: Color(0xFFF1F4F1)),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32))),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Keep My Account',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(width: 10),
                  Icon(Icons.verified_user_outlined, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: onProceed,
              child: const Text('Proceed with account deletion',
                  style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// --- SCREEN 02 ---
class StepTwoScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onDelete;
  const StepTwoScreen({super.key, required this.onBack, required this.onDelete});

  @override
  State<StepTwoScreen> createState() => _StepTwoScreenState();
}

class _StepTwoScreenState extends State<StepTwoScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isDeleteEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _isDeleteEnabled = _controller.text.trim() == "DELETE";
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProgressBar(step: 2),
          const SizedBox(height: 32),
          const Text("Final\nVerification.",
              style: TextStyle(
                  color: AppColors.primaryGreen, fontSize: 42, fontWeight: FontWeight.w900, height: 1.1)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration:
                BoxDecoration(color: AppColors.pinkWarning, borderRadius: BorderRadius.circular(12)),
            child: Stack(
              children: [
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Icon(Icons.warning_amber_rounded,
                      size: 80, color: AppColors.warningRed.withValues(alpha:0.1)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("This action is irreversible.",
                        style: TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 12),
                    Text(
                        "Deleting your account will result in the immediate and permanent removal of all crop histories, yield data, and active soil health profiles.",
                        style: TextStyle(color: AppColors.warningRed.withValues(alpha:0.8), fontSize: 14, height: 1.4)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.cardGrey, borderRadius: BorderRadius.circular(24)),
            child: Column(
              children: [
                const Text("CONFIRMATION REQUIRED",
                    style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 24),
                const Text.rich(TextSpan(
                    text: "To confirm, please type ",
                    children: [
                      TextSpan(text: "DELETE", style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: " below.")
                    ])),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: "Type 'DELETE' to proceed",
                    filled: true,
                    fillColor: Colors.white,
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _isDeleteEnabled ? widget.onDelete : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warningRed,
                      disabledBackgroundColor: Colors.grey.shade400,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                      elevation: _isDeleteEnabled ? 8 : 0,
                    ),
                    child: const Text('Permanently Delete Account',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: widget.onBack,
                  child: const Text('Go Back',
                      style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- SCREEN 03: SUCCESS DELETION ---
class SuccessDeletionScreen extends StatelessWidget {
  const SuccessDeletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(flex: 2),
        // Success Icon with Outer Ring
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha:0.03), width: 1.5),
              color: Colors.black.withValues(alpha:0.02),
            ),
            child: Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black.withValues(alpha:0.05), width: 1),
                  color: Colors.white,
                ),
                child: const Icon(
                  Icons.check,
                  size: 80,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 48),
        const Text(
          "Success.",
          style: TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryGreen,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            children: [
              const Text(
                "Your account has been successfully deleted. Thank you for being part of the VISAIA community.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF444444),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "All personal data has been securely removed from our active records.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textBody.withValues(alpha:0.7),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: 160,
          height: 64,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            ),
            child: const Text(
              "Back",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          "REDIRECTING TO MAIN SITE IN 10 SECONDS",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.5,
            color: Colors.black.withValues(alpha:0.3),
          ),
        ),
        const Spacer(flex: 3),
        // Footer
        Padding(
          padding: const EdgeInsets.only(bottom: 40.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "VISAIA",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.black.withValues(alpha:0.2),
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha:0.2))),
              const SizedBox(width: 12),
              Text(
                "VERDANT HARVEST SYSTEM",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Colors.black.withValues(alpha:0.2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- SHARED COMPONENTS ---
class ProgressBar extends StatelessWidget {
  final int step;
  const ProgressBar({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            height: 6,
            width: 60,
            decoration: BoxDecoration(
                color: step == 1 ? AppColors.primaryGreen : AppColors.activeGreen,
                borderRadius: BorderRadius.circular(10))),
        const SizedBox(width: 8),
        Container(
            height: 6,
            width: 60,
            decoration: BoxDecoration(
                color: step == 2 ? AppColors.primaryGreen : Colors.grey.withValues(alpha:0.2),
                borderRadius: BorderRadius.circular(10))),
        const Spacer(),
        Text('STEP 0$step OF 02', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class CriticalBadge extends StatelessWidget {
  const CriticalBadge({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppColors.criticalBadge, borderRadius: BorderRadius.circular(8)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.warning_amber_rounded, color: AppColors.warningRed, size: 16),
        SizedBox(width: 6),
        Text('CRITICAL ACTION',
            style: TextStyle(color: AppColors.warningRed, fontWeight: FontWeight.w800, fontSize: 12)),
      ]),
    );
  }
}

class SecurityDataCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color? color;

  const SecurityDataCard({super.key, required this.icon, required this.title, required this.description, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: color ?? Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 28),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(fontSize: 14, color: AppColors.textBody, height: 1.4)),
        ],
      ),
    );
  }
}