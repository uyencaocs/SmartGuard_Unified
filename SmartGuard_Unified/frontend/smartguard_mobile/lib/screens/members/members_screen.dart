import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';

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
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.request('GET', '/api/members') as List<dynamic>;
      if (mounted) {
        setState(() {
          _members = res.map((e) => MemberModel.fromJson(e as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showShareDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chia sẻ quyền cho người nhà'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nhập email của người nhà đã đăng ký tài khoản trên hệ thống để cấp quyền quan sát camera.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email thành viên',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ApiClient.request('POST', '/api/members/share', body: {
                  'memberEmail': email,
                  'canAcknowledge': true,
                });
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã chia sẻ quyền truy cập cho $email'),
                    backgroundColor: AppTheme.statusArmed,
                  ),
                );
                _loadMembers();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.statusAlarm),
                );
              }
            },
            child: const Text('Chia sẻ'),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeAccess(MemberModel member) async {
    try {
      await ApiClient.request('DELETE', '/api/members/${member.id}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thu hồi quyền truy cập thành công.')),
      );
      _loadMembers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.statusAlarm),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thành viên gia đình'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: _showShareDialog,
            tooltip: 'Chia sẻ cho thành viên mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? const Center(
                  child: Text(
                    'Chưa chia sẻ quyền cho thành viên nào.\nNhấn nút thêm ở trên để chia sẻ cho người thân.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE2E8F0),
                          child: Icon(Icons.person, color: AppTheme.primaryBlue),
                        ),
                        title: Text(member.memberEmail, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Tên: ${member.memberUsername} • Quyền: ${member.deviceName ?? "Tất cả camera"}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.statusAlarm),
                          onPressed: () => _revokeAccess(member),
                          tooltip: 'Thu hồi quyền',
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
