import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/emergency_service.dart';
import '../../services/foreground_service_controller.dart';

class MembersScreen extends StatefulWidget {
  final bool isTab;
  const MembersScreen({super.key, this.isTab = false});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isLoading = true;
  List<EmergencyContactModel> _contacts = [];
  List<MemberModel> _sharedMembers = [];

  final List<String> _relationshipOptions = [
    'Chủ nhà',
    'Vợ / Chồng',
    'Bố / Mẹ',
    'Con cái',
    'Anh / Chị / Em',
    'Hàng xóm thân thiết',
    'Bảo vệ tòa nhà',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadEmergencyContacts();
    await _loadSharedMembers();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadEmergencyContacts() async {
    final list = await EmergencyService.getContacts();
    if (mounted) {
      setState(() => _contacts = list);
    }
  }

  Future<void> _loadSharedMembers() async {
    try {
      final res = await ApiClient.request('GET', '/api/members') as List<dynamic>;
      if (mounted) {
        setState(() {
          _sharedMembers = res.map((e) => MemberModel.fromJson(e as Map<String, dynamic>)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _showAddContactDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String rel = 'Bố / Mẹ';
    bool callAlert = true;
    bool smsAlert = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: AppTheme.coralPink),
              SizedBox(width: 8),
              Text('Thêm Người Thân Khẩn Cấp', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Hệ thống SmartGuard sẽ tự động gọi điện hoặc gửi tin nhắn SMS khi phát hiện có kẻ gian đột nhập.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Họ và tên *',
                    hintText: 'Ví dụ: Bác Tuấn, Bố Hùng...',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Số điện thoại khẩn cấp *',
                    hintText: '0912 345 678',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: rel,
                  decoration: InputDecoration(
                    labelText: 'Mối quan hệ',
                    prefixIcon: const Icon(Icons.favorite_border),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: _relationshipOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => rel = val);
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tự động gọi điện khi có sự cố', style: TextStyle(fontSize: 13)),
                  value: callAlert,
                  activeColor: AppTheme.coralPink,
                  onChanged: (val) => setDialogState(() => callAlert = val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tự động gửi SMS vị trí & ảnh', style: TextStyle(fontSize: 13)),
                  value: smsAlert,
                  activeColor: AppTheme.coralPink,
                  onChanged: (val) => setDialogState(() => smsAlert = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                if (name.isEmpty || phone.isEmpty) return;

                Navigator.pop(ctx);
                final newContact = EmergencyContactModel(
                  id: 'contact_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  phone: phone,
                  relationship: rel,
                  isCallAlert: callAlert,
                  isSmsAlert: smsAlert,
                );

                await EmergencyService.addContact(newContact);
                await _loadEmergencyContacts();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã thêm $name vào danh sách báo khẩn cấp'),
                      backgroundColor: AppTheme.statusArmed,
                    ),
                  );
                }
              },
              child: const Text('Lưu người thân'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteContact(EmergencyContactModel c) async {
    await EmergencyService.deleteContact(c.id);
    await _loadEmergencyContacts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa ${c.name} khỏi danh sách khẩn cấp'),
          backgroundColor: AppTheme.textSecondary,
        ),
      );
    }
  }

  Future<void> _testEmergencyAlert(EmergencyContactModel c) async {
    final result = await EmergencyService.dispatchEmergencyAlert(
      reason: 'Báo động thử nghiệm từ ứng dụng SmartGuard',
    );

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.phone_in_talk, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Đã kết nối khẩn cấp!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hệ thống đã giả lập quay số tự động đến ${c.name} (${c.phone}).'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.creamBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  result['summary']?.toString() ?? 'Tín hiệu viễn thông đang sẵn sàng phản hồi sự cố.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              icon: const Icon(Icons.call, color: Colors.white, size: 18),
              label: const Text('Gọi ngay qua SIM', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                Navigator.pop(ctx);
                await ForegroundServiceController.callEmergency(c.phone);
              },
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar matching Mockup "Thành viên"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (!widget.isTab && Navigator.of(context).canPop())
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                          onPressed: () => Navigator.pop(context),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.borderWarm),
                          ),
                          child: const Icon(Icons.people_alt_outlined, color: AppTheme.coralPink, size: 20),
                        ),
                      const SizedBox(width: 10),
                      const Text(
                        'Thành viên',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
                    onPressed: _loadData,
                    tooltip: 'Làm mới',
                  ),
                ],
              ),
            ),

            // Tab Bar: Người thân khẩn cấp & Tài khoản chia sẻ
            TabBar(
              controller: _tabCtrl,
              indicatorColor: AppTheme.coralPink,
              labelColor: AppTheme.coralPink,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: [
                Tab(
                  icon: const Icon(Icons.emergency_share),
                  text: 'Người thân khẩn cấp (${_contacts.length})',
                ),
                Tab(
                  icon: const Icon(Icons.app_registration),
                  text: 'Chia sẻ tài khoản (${_sharedMembers.length})',
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Body
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildEmergencyContactsTab(),
                  _buildSharedMembersTab(),
                ],
              ),
            ),

            // Cute Baby Capybaras illustration at the bottom (matching mockup!)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Image.asset(
                'assets/images/create_accout.png',
                height: 70,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/Capybara.jpg',
                  height: 60,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),

            // Bottom Add Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.coralPink.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: _showAddContactDialog,
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    label: const Text(
                      '+ Thêm người thân khẩn cấp',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactsTab() {
    if (_isLoading && _contacts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_contacts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/save.png',
                height: 100,
                errorBuilder: (_, __, ___) => const Icon(Icons.contact_phone_outlined, size: 64, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chưa có danh bạ khẩn cấp',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Thêm số điện thoại người thân để hệ thống tự động gọi điện hoặc gửi SMS khi phát hiện đột nhập.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: _contacts.length,
      itemBuilder: (ctx, index) {
        final c = _contacts[index];
        final isOwner = c.relationship == 'Chủ nhà';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderWarm),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isOwner ? const Color(0xFFDCE8F3) : const Color(0xFFFFECE8),
                  child: Text(
                    c.name.isNotEmpty ? c.name[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isOwner ? const Color(0xFF26384F) : AppTheme.coralPink,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name and relationship badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Badge matching mockup
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOwner ? const Color(0xFFE0F2FE) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              c.relationship,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isOwner ? const Color(0xFF0284C7) : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.phone,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),

                // Call test button
                IconButton(
                  icon: const Icon(Icons.phone_forwarded, color: Color(0xFF10B981)),
                  tooltip: 'Thử nghiệm gọi tự động',
                  onPressed: () => _testEmergencyAlert(c),
                ),

                // Popup menu for delete
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
                  onSelected: (val) {
                    if (val == 'delete') _deleteContact(c);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: AppTheme.coralPink, size: 18),
                          SizedBox(width: 8),
                          Text('Xóa liên hệ', style: TextStyle(color: AppTheme.coralPink)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSharedMembersTab() {
    if (_sharedMembers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.share_outlined, size: 64, color: AppTheme.textSecondary),
              const SizedBox(height: 16),
              const Text(
                'Chưa có tài khoản nào được chia sẻ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
                  const Text(
                    'Bạn có thể cấp quyền truy cập camera cho người thân qua email đăng ký.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _showShareAccountDialog,
                    icon: const Icon(Icons.share),
                    label: const Text('Chia sẻ qua Email'),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _showShareAccountDialog,
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Chia sẻ thêm tài khoản'),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: _sharedMembers.length,
                itemBuilder: (ctx, i) {
                  final m = _sharedMembers[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEDE9FE),
                        child: Icon(Icons.person, color: AppTheme.royalPurple),
                      ),
                      title: Text(m.memberEmail, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Tên: ${m.memberUsername} • Quyền: ${m.deviceName ?? "Toàn bộ camera"}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.coralPink),
                        tooltip: 'Thu hồi quyền truy cập',
                        onPressed: () => _revokeSharedMember(m),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }

      Future<void> _showShareAccountDialog() async {
        final emailCtrl = TextEditingController();
        bool canAck = true;
        await showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDlg) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Chia sẻ quyền truy cập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email tài khoản người thân *',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cho phép tắt chuông / xác nhận cảnh báo', style: TextStyle(fontSize: 13)),
                    value: canAck,
                    activeColor: AppTheme.coralPink,
                    onChanged: (v) => setDlg(() => canAck = v),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coralPink, foregroundColor: Colors.white),
                  onPressed: () async {
                    final email = emailCtrl.text.trim();
                    if (email.isEmpty) return;
                    Navigator.pop(ctx);
                    try {
                      await ApiClient.request('POST', '/api/members/share', body: {
                        'memberEmail': email,
                        'canAcknowledge': canAck,
                      });
                      await _loadSharedMembers();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã chia sẻ quyền truy cập cho $email'), backgroundColor: AppTheme.statusArmed),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e'), backgroundColor: AppTheme.statusAlarm),
                        );
                      }
                    }
                  },
                  child: const Text('Chia sẻ'),
                ),
              ],
            ),
          ),
        );
      }

      Future<void> _revokeSharedMember(MemberModel m) async {
        try {
          await ApiClient.request('DELETE', '/api/members/${m.id}');
          await _loadSharedMembers();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Đã thu hồi quyền của ${m.memberEmail}'), backgroundColor: AppTheme.statusArmed),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$e'), backgroundColor: AppTheme.statusAlarm),
            );
          }
        }
      }
}
