import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_4/page/delivery_detail.dart';
import 'package:flutter_application_4/widgets/rider_footer.dart';
// 🔽 เพิ่ม import หน้ารายละเอียดงาน (แก้ path ให้ตรงโปรเจ็กต์)


class JobsPage extends StatefulWidget {
  final String userId;
  const JobsPage({super.key, required this.userId});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  static const _brandRed = Color(0xFFE96356);
  static const String kWaiting = 'รอไรเดอร์มารับสินค้า'; // ✅ ฟิลเตอร์สถานะตามที่ต้องการ

  final Map<String, String> _addressCache = {};

  Future<String> _loadAddress(String addressId) async {
    if (addressId.isEmpty) return '-';
    if (_addressCache.containsKey(addressId)) return _addressCache[addressId]!;
    final snap = await FirebaseFirestore.instance
        .collection('user_address')
        .doc(addressId)
        .get();
    final data = snap.data();
    final text = data == null ? '-' : (data['address'] ?? '-').toString();
    _addressCache[addressId] = text;
    return text;
  }

  // งาน “รอไรเดอร์” และยังไม่มีคนรับ
  Stream<QuerySnapshot<Map<String, dynamic>>> _jobsStream() {
    return FirebaseFirestore.instance
        .collection('delivery')
        .where('status', isEqualTo: kWaiting)
        .where('riderid', isNull: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: Image.asset('assets/images/พื้นหลังแอพ.png', fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black38],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                color: _brandRed,
                border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: const Text(
                'รายการงาน',
                style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black,
                  shadows: [Shadow(blurRadius: 1.5, offset: Offset(0.8, 0.8), color: Colors.white)],
                ),
              ),
            ),

            // กล่องโปร่งใสด้านใน + รายการการ์ด
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.black, width: 1.8),
                      ),
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _jobsStream(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snap.hasError) {
                            return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
                          }
                          final docs = snap.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return const Center(child: Text('ยังไม่มีงานที่รอรับ'));
                          }

                          return Scrollbar(
                            thickness: 6, radius: const Radius.circular(12),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final doc = docs[i];
                                final d = doc.data();
                                final deliveryDocId = doc.id; // ใช้ id เอกสารจริง
                                final deliveryId =
                                    (d['deliveryid'] ?? deliveryDocId).toString();
                                final addrSendId = (d['addressid_sender'] ?? '').toString();
                                final addrRecvId = (d['addressid_receiver'] ?? '').toString();
                                final amount = d['amount'] is int
                                    ? d['amount'] as int
                                    : int.tryParse('${d['amount']}') ?? 0;

                                return FutureBuilder<List<String>>(
                                  future: Future.wait([
                                    _loadAddress(addrSendId),
                                    _loadAddress(addrRecvId),
                                  ]),
                                  builder: (context, addrSnap) {
                                    final from =
                                        addrSnap.data?.elementAtOrNull(0) ?? 'กำลังโหลดที่อยู่รับ...';
                                    final to =
                                        addrSnap.data?.elementAtOrNull(1) ?? 'กำลังโหลดที่อยู่ส่ง...';

                                    return _JobCard(
                                      title: 'เลขรายการสินค้า $deliveryId',
                                      from: 'ที่รับ $from',
                                      to: 'ที่ส่ง $to',
                                      qty: '$amount ชิ้น',
                                      // 🔽 กดแล้วไปหน้า "รายละเอียดงาน"
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DeliveryDetailPage(
                                              userId: widget.userId,
                                              deliveryDocId: deliveryDocId,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),

      bottomNavigationBar: RiderFooterNavBar(
        currentIndex: 0,
        userId: widget.userId,
      ),
    );
  }
}

// การ์ดหน้าตาตามรูป: มีแค่ > ทางขวา
class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.title,
    required this.from,
    required this.to,
    required this.qty,
    required this.onTap,
  });

  final String title;
  final String from;
  final String to;
  final String qty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black54, width: 1.3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 6),
                Text(from, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, height: 1.35)),
                const SizedBox(height: 2),
                Text(to, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, height: 1.35)),
                const SizedBox(height: 6),
                Text('จำนวนสินค้า $qty',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.chevron_right, size: 26),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
