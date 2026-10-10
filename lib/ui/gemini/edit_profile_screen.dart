import 'package:flutter/material.dart';

import 'auth_screens.dart';

/// Edit Profile page of the Tiffie redesign. Controllers and callbacks are
/// parameters; the email is the sign-in email and is read-only.
class GEditProfile extends StatelessWidget {
  final TextEditingController name, phone, address;
  final String email, area;
  final List<String> areas;
  final ValueChanged<String> onArea;
  final String? error;
  final bool saving, loaded;
  final VoidCallback onSave, onPassword;
  const GEditProfile({
    super.key,
    required this.name,
    required this.phone,
    required this.address,
    required this.email,
    required this.area,
    required this.areas,
    required this.onArea,
    required this.error,
    required this.saving,
    required this.loaded,
    required this.onSave,
    required this.onPassword,
  });

  InputDecoration _dec() => InputDecoration(
    filled: true,
    fillColor: GColors.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: GColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: GColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: GColors.green, width: 1.5),
    ),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      t,
      style: gText(12.5, w: FontWeight.w700, c: GColors.charcoal),
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(brightness: Brightness.light),
    child: Scaffold(
      backgroundColor: GColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: GColors.alt(const Color(0xFFF1ECE2), GColors.chip),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_back, color: GColors.charcoal),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Edit Profile',
                        style: gText(24, w: FontWeight.w800, c: GColors.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: !loaded && error == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('FULL NAME'),
                          TextField(
                            controller: name,
                            textCapitalization: TextCapitalization.words,
                            style: gText(14, c: GColors.charcoal),
                            decoration: _dec(),
                          ),
                          _label('EMAIL ADDRESS'),
                          TextField(
                            controller: TextEditingController(text: email),
                            readOnly: true,
                            style: gText(14, c: GColors.grey),
                            decoration: _dec(),
                          ),
                          _label('PHONE NUMBER'),
                          TextField(
                            controller: phone,
                            keyboardType: TextInputType.phone,
                            style: gText(14, c: GColors.charcoal),
                            decoration: _dec(),
                          ),
                          _label('DELIVERY AREA'),
                          areas.isEmpty
                              ? const SizedBox.shrink()
                              : DropdownButtonFormField<String>(
                                  initialValue: areas.contains(area)
                                      ? area
                                      : null,
                                  isExpanded: true,
                                  style: gText(14, c: GColors.charcoal),
                                  decoration: _dec(),
                                  items: [
                                    for (final a in areas)
                                      DropdownMenuItem(
                                        value: a,
                                        child: Text(a),
                                      ),
                                  ],
                                  onChanged: (v) => onArea(v ?? ''),
                                ),
                          _label('HOUSE, BUILDING & STREET'),
                          TextField(
                            controller: address,
                            minLines: 2,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            style: gText(14, c: GColors.charcoal),
                            decoration: _dec().copyWith(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: GColors.line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: GColors.line),
                              ),
                            ),
                          ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Text(
                                error!,
                                style: gText(12.5, c: const Color(0xFFB3261E)),
                              ),
                            ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: onPassword,
                            icon: Icon(
                              Icons.lock_outline,
                              color: GColors.ink,
                              size: 20,
                            ),
                            label: Text(
                              'Change password',
                              style: gText(
                                14,
                                w: FontWeight.w700,
                                c: GColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: GButton(
                saving ? 'Saving...' : 'Save Changes',
                color: GColors.green,
                onPressed: saving || !loaded ? null : onSave,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
