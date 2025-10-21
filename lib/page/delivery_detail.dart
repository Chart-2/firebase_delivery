import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryDetailPage extends StatefulWidget {
  final String userId;        // ไรเดอร์ที่ล็อกอิน
  final String deliveryDocId; // documentId ของ delivery
  const DeliveryDetailPage({
    super.key,
    required this.userId,
    required this.deliveryDocId,
  });

  @override
  State<DeliveryDetailPage> createState() => _DeliveryDetailPageState();
}

class _DeliveryDetailPageState extends State<DeliveryDetailPage> {
  static const _brandRed = Color(0xFFE96356);
  static const String kWaiting = 'รอไรเดอร์มารับสินค้า';

  final _db = FirebaseFirestore.instance;
  final Map<String, String> _addressCache = {};
  final Map<String, String> _userNameCache = {};
  final Map<String, String> _vehicleLabelCache = {};

  Future<String> _loadAddress(String addressId) async {
    if (addressId.isEmpty) return '-';
    if (_addressCache.containsKey(addressId)) return _addressCache[addressId]!;
    final snap = await _db.collection('user_address').doc(addressId).get();
    final data = snap.data();
    final text = data == null ? '-' : (data['address'] ?? '-').toString();
    _addressCache[addressId] = text;
    return text;
  }

  Future<String> _loadUserName(String userId) async {
    if (userId.isEmpty) return '-';
    if (_userNameCache.containsKey(userId)) return _userNameCache[userId]!;
    final snap = await _db.collection('user').doc(userId).get();
    final data = snap.data();
    final name = data == null ? '-' : (data['name'] ?? '-').toString();
    _userNameCache[userId] = name;
    return name;
  }

  Future<String> _loadVehicleLabel(String riderUserId) async {
    if (riderUserId.isEmpty) return '-';
    if (_vehicleLabelCache.containsKey(riderUserId)) {
      return _vehicleLabelCache[riderUserId]!;
    }
    // หาเอกสารรถ (คอลเลกชัน rider_car มีหลาย doc? เอา doc แรกของ user นี้)
    final q = await _db
        .collection('rider_car')
        .where('userid', isEqualTo: riderUserId)
        .limit(1)
        .get();
    if (q.docs.isEmpty) {
      _vehicleLabelCache[riderUserId] = '-';
      return '-';
    }
    final d = q.docs.first.data();
    final carType = (d['car_type'] ?? '').toString();
    final plate   = (d['plate_number'] ?? '').toString();
    final label = carType.isEmpty && plate.isEmpty ? '-' : '$carType : $plate';
    _vehicleLabelCache[riderUserId] = label;
    return label;
  }

  // ===== รับงานได้ครั้งเดียว (transaction) =====
  Future<void> _acceptJob() async {
    final deliveryRef = _db.collection('delivery').doc(widget.deliveryDocId);
    final riderStateRef = _db.collection('rider_state').doc(widget.userId);

    try {
      await _db.runTransaction((tx) async {
        final riderState = await tx.get(riderStateRef);
        final active = riderState.data()?['active_delivery_id'];
        if (active != null && (active as String).isNotEmpty) {
          throw Exception('คุณมีงานที่กำลังทำอยู่ (ID: $active)');
        }

        final delSnap = await tx.get(deliveryRef);
        if (!delSnap.exists) throw Exception('งานนี้ถูกลบแล้ว');
        final data = delSnap.data()!;
        if ((data['status'] ?? '') != kWaiting || data['riderid'] != null) {
          throw Exception('งานนี้ถูกคนอื่นรับไปแล้ว');
        }

        tx.update(deliveryRef, {
          'riderid': widget.userId,
          'status': 'กำลังไปรับสินค้า',
          'updated_at': FieldValue.serverTimestamp(),
        });
        tx.set(
          riderStateRef,
          {
            'active_delivery_id': widget.deliveryDocId,
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รับงานสำเร็จ')),
      );
      Navigator.pop(context); // กลับไปหน้ารายการ
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('รับงานไม่ได้: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveryDoc = _db.collection('delivery').doc(widget.deliveryDocId);

    return Scaffold(
      body: Stack(children: [
        // พื้นหลัง
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
            // Header + back
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                color: _brandRed,
                border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'รายละเอียดงาน',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          shadows: [
                            Shadow(
                              blurRadius: 1.5,
                              offset: Offset(0.8, 0.8),
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // balance ปุ่ม back
                ],
              ),
            ),

            // เนื้อหา
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.78),
                        border: Border.all(color: Colors.black, width: 1.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: deliveryDoc.snapshots(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snap.hasError || !snap.hasData || !snap.data!.exists) {
                            return Center(child: Text('ไม่พบงาน: ${snap.error ?? ''}'));
                          }
                          final d = snap.data!.data()!;
                          final status = (d['status'] ?? '').toString();
                          final amount = d['amount'] is int
                              ? d['amount'] as int
                              : int.tryParse('${d['amount']}') ?? 0;
                          final detail = (d['detail'] ?? '').toString();
                          final pic1 = (d['picture_status1'] ?? '').toString();
                          final senderAddrId = (d['addressid_sender'] ?? '').toString();
                          final receiverAddrId = (d['addressid_receiver'] ?? '').toString();
                          final riderId = (d['riderid'] ?? '')?.toString() ?? '';

                          return FutureBuilder(
                            future: Future.wait<String>([
                              _loadAddress(senderAddrId),
                              _loadAddress(receiverAddrId),
                              if (riderId.isNotEmpty) _loadUserName(riderId) else Future.value('-'),
                              if (riderId.isNotEmpty) _loadVehicleLabel(riderId) else Future.value('-'),
                            ]),
                            builder: (context, addrSnap) {
                              final from = addrSnap.data?.elementAtOrNull(0) ?? '-';
                              final to = addrSnap.data?.elementAtOrNull(1) ?? '-';
                              final riderName = riderId.isNotEmpty
                                  ? (addrSnap.data?.elementAtOrNull(2) ?? '-')
                                  : '-';
                              final vehicleLabel = riderId.isNotEmpty
                                  ? (addrSnap.data?.elementAtOrNull(3) ?? '-')
                                  : '-';

                              return ListView(
                                padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                                children: [
                                  _SectionCard(
                                    child: _TwoSideRow(
                                      left: 'สถานะสินค้า :  $status',
                                      right: '',
                                    ),
                                  ),

                                  // ที่อยู่ผู้ส่ง
                                  _SectionCard(
                                    child: _RightChevronTile(
                                      title: 'ที่อยู่ของผู้ส่ง',
                                      content:
                                          from.isEmpty ? '-' : from,
                                      onTap: () {
                                        // TODO: เปิดแผนที่/นำทางไปยังที่รับ
                                      },
                                    ),
                                  ),

                                  // ที่อยู่ผู้รับ
                                  _SectionCard(
                                    child: _RightChevronTile(
                                      title: 'ที่อยู่ของผู้รับ',
                                      content: to.isEmpty ? '-' : to,
                                      onTap: () {
                                        // TODO: เปิดแผนที่/นำทางไปยังที่ส่ง
                                      },
                                    ),
                                  ),

                                  // จำนวนสินค้า (ชิ้น)
                                  _SectionCard(
                                    child: _TwoSideRow(
                                      left: 'จำนวนสินค้า :  $amount',
                                      right: 'ชิ้น',
                                    ),
                                  ),

                                  // รายละเอียดสินค้า
                                  _SectionCard(
                                    child: _BlockTile(
                                      title: 'รายละเอียดสินค้า',
                                      content: detail.isEmpty ? '-' : detail,
                                    ),
                                  ),

                                  // ไรเดอร์/ยานพาหนะ
                                  _SectionCard(
                                    child: _RightChevronTile(
                                      title: riderId.isNotEmpty
                                          ? 'ไรเดอร์ที่ส่งสินค้า : $riderName'
                                          : 'ยานพาหนะที่ใช้',
                                      content: riderId.isNotEmpty ? vehicleLabel : 'กดเพื่อเลือก/ดู',
                                      onTap: () {
                                        // TODO: แสดง/เลือกยานพาหนะ หรือโปรไฟล์ไรเดอร์
                                      },
                                    ),
                                  ),

                                  // รูปสินค้า
                                  _SectionCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('รูปสินค้า',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 8),
                                        AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: Colors.black54, width: 1.2),
                                              image: pic1.isNotEmpty
                                                  ? DecorationImage(
                                                      image: NetworkImage(pic1),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                            ),
                                            child: pic1.isEmpty
                                                ? const Center(
                                                    child: Text('ไม่มีรูปสินค้า'),
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 12),
                                  if (status == kWaiting && (riderId.isEmpty))
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        onPressed: _acceptJob,
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                        ),
                                        child: const Text('รับงาน'),
                                      ),
                                    ),
                                ],
                              );
                            },
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
    );
  }
}

/* ---------------------- small UI pieces ---------------------- */

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2).withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black54, width: 1.2),
      ),
      child: child,
    );
  }
}

class _TwoSideRow extends StatelessWidget {
  const _TwoSideRow({required this.left, required this.right});
  final String left;
  final String right;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(left,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        if (right.isNotEmpty)
          Text(right,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _RightChevronTile extends StatelessWidget {
  const _RightChevronTile({
    required this.title,
    required this.content,
    required this.onTap,
  });
  final String title;
  final String content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(height: 1.3),
            ),
          ]),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right),
      ]),
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({required this.title, required this.content});
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(content.isEmpty ? '-' : content),
      ),
    ]);
  }
}
