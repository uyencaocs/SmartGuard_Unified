import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/capybara_widgets.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  bool _isLoading = true;
  List<MemberModel> _members = [];

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.request('GET', '/api/members');
      if (res is List) {
        setState(() {
          _members = res.map((m) => MemberModel.fromJson(m as Map<String, dynamic>)).toList();
        });
      }
    } catch (_) {
      if (_members.isEmpty) {
        _members = [
          MemberModel(
            id: '1',
            ownerId: 'owner-1',
            userId: 'user-1',
            username: 'Quỳnh Hương',
            email: 'quynhhuong@gmail.com',
            roleInHousehold: 'Chủ nhà',
            canArmDisarm: true,
            canViewCameras: true,
            joinedAt: DateTime.now(),
          ),
          MemberModel(
            id: '2',
            ownerId: 'owner-1',
            userId: 'user-2',
            username: 'Minh Trí',
            email: 'minhtri@gmail.com',
            roleInHousehold: 'Thành viên',
            canArmDisarm: true,
            canViewCameras: true,
            joinedAt: DateTime.now(),
          ),
          MemberModel(
            id: '3',
            ownerId: 'owner-1',
            userId: 'user-3',
            username: 'Bảo Anh',
            email: 'baoanh@gmail.com',
            roleInHousehold: 'Thành viên',
            canArmDisarm: false,
            canViewCameras: true,
            joinedAt: DateTime.now(),
          ),
        ];
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddMemberDialog() {
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Thêm thành viên gia đình'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nhập email của người thân để mời vào ngôi nhà an ninh SmartGuard:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'nguoithan@gmail.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isNotEmpty) {
                try {
                  await ApiClient.request('POST', '/api/members', body: {
                    'email': email,
                    'roleInHousehold': 'Thành viên',
                    'canArmDisarm': true,
                    'canViewCameras': true,
                  });
                } catch (_) {}
                if (mounted) _fetchMembers();
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
            child: const Text('Gửi lời mời', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmCream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Thành viên'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
                    : ListView.builder(
                        itemCount: _members.length,
                        itemBuilder: (context, index) {
                          final mem = _members[index];
                          final isOwner = mem.roleInHousehold == 'Chủ nhà' || mem.roleInHousehold == 'Owner';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFF1E7DD)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppTheme.capyPeach,
                                  child: Text(
                                    mem.username.isNotEmpty ? mem.username[0].toUpperCase() : 'U',
                                    style: const TextStyle(
                                      color: AppTheme.capyBrownDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mem.username,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        mem.email,
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isOwner ? AppTheme.capyPeach : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    mem.roleInHousehold,
                                    style: TextStyle(
                                      color: isOwner ? AppTheme.capyBrownDark : AppTheme.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // Capybara family badge at bottom
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1E7DD)),
                ),
                child: const Row(
                  children: [
                    CapybaraAvatar(size: 36),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Capybara gia đình luôn bảo bọc và chia sẻ an toàn với mọi người thân!',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),

              CapybaraGradientButton(
                text: '+ Thêm thành viên',
                onPressed: _showAddMemberDialog,
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}
