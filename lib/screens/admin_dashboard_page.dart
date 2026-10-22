import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/address_search_service.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/bar_service.dart';
import '../services/sponsor_service.dart';
import '../theme/app_theme.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final BarService _barService = BarService();
  final SponsorService _sponsorService = SponsorService();
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard Admin'),
          backgroundColor: AppColors.deepOcean,
          elevation: 0,
          toolbarHeight: isMobile ? 56 : 80,
          bottom: TabBar(
            onTap: (index) => setState(() => _selectedTabIndex = index),
            isScrollable: isMobile,
            tabs: const [
              Tab(icon: Icon(Icons.store), text: 'Locali'),
              Tab(icon: Icon(Icons.handshake), text: 'Sponsor'),
              Tab(icon: Icon(Icons.people), text: 'Utenti'),
            ],
          ),
          actions: isMobile
              ? [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (String result) {
                      if (result == 'logout') {
                        _logout(context);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'user',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _authService.currentUser?.email ??
                                        'Non autenticato',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem<String>(
                            value: 'logout',
                            child: Row(
                              children: const [
                                Icon(Icons.logout, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Logout'),
                              ],
                            ),
                          ),
                        ],
                  ),
                ]
              : [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: Text(
                        _authService.currentUser?.email ?? 'Non autenticato',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton.icon(
                      onPressed: () => _logout(context),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                ],
        ),
        body: TabBarView(
          children: [
            _buildBarsTab(context),
            _buildSponsorsTab(context),
            _buildUsersTab(context),
          ],
        ),
        floatingActionButton: _selectedTabIndex == 0
            ? FloatingActionButton(
                backgroundColor: AppColors.ocean,
                onPressed: () => _showAddBarDialog(context),
                child: const Icon(Icons.add),
              )
            : _selectedTabIndex == 1
            ? FloatingActionButton(
                backgroundColor: AppColors.ocean,
                onPressed: () => _showAddSponsorDialog(context),
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }

  Widget _buildBarsTab(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Gestione Locali',
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: AppColors.deepOcean,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddBarDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi Locale'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ocean,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 24,
                  vertical: isMobile ? 8 : 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildBarsManagement(context, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildSponsorsTab(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Gestione Sponsor',
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: AppColors.deepOcean,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddSponsorDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi Sponsor'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ocean,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 24,
                  vertical: isMobile ? 8 : 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSponsorsManagement(context, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Utenti Registrati',
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: AppColors.deepOcean,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Visualizza gli utenti registrati all\'applicazione',
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () => _showAddUserDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Aggiungi utente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ocean,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildUsersManagement(context, isMobile),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddUserDialog(BuildContext context) async {
    final superAdmin = await _adminService.isUserSuperAdmin();
    if (!context.mounted) return;
    final user = await showDialog<_NewManagedUser>(
      context: context,
      builder: (_) => _AddUserDialog(canAssignAdminRoles: superAdmin),
    );
    if (user == null || !context.mounted) return;

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('createManagedUser');
      await callable.call({
        'firstName': user.firstName,
        'lastName': user.lastName,
        'email': user.email,
        'password': user.password,
        'role': user.role,
        'phone': user.phone,
        'residence': user.residence,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utente creato correttamente')),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;
      final message = error.message ?? 'Creazione utente non riuscita';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la creazione: $error')),
      );
    }
  }

  Widget _buildBarsManagement(BuildContext context, bool isMobile) {
    return StreamBuilder<List<BarSpot>>(
      stream: _barService.watchBars(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Errore: ${snapshot.error}'));
        }

        final bars = snapshot.data ?? [];

        if (bars.isEmpty) {
          return const Center(child: Text('Nessun locale trovato'));
        }

        return Column(
          children: [
            Text(
              'Locali registrati: ${bars.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            isMobile
                ? ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: bars.length,
                    itemBuilder: (context, index) {
                      final bar = bars[index];
                      return _buildBarCard(context, bar);
                    },
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Nome')),
                        DataColumn(label: Text('Città')),
                        DataColumn(label: Text('Indirizzo')),
                        DataColumn(label: Text('Refill Info')),
                        DataColumn(label: Text('Azioni')),
                      ],
                      rows: bars
                          .map((bar) => _buildBarTableRow(context, bar))
                          .toList(),
                    ),
                  ),
          ],
        );
      },
    );
  }

  Widget _buildSponsorsManagement(BuildContext context, bool isMobile) {
    return StreamBuilder<List<SponsorSpot>>(
      stream: _sponsorService.watchSponsors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Errore: ${snapshot.error}'));
        }

        final sponsors = snapshot.data ?? [];

        if (sponsors.isEmpty) {
          return const Center(child: Text('Nessuno sponsor trovato'));
        }

        return Column(
          children: [
            Text(
              'Sponsor registrati: ${sponsors.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            isMobile
                ? ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sponsors.length,
                    itemBuilder: (context, index) {
                      final sponsor = sponsors[index];
                      return _buildSponsorCard(context, sponsor);
                    },
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Nome')),
                        DataColumn(label: Text('Categoria')),
                        DataColumn(label: Text('Indirizzo')),
                        DataColumn(label: Text('Featured')),
                        DataColumn(label: Text('Azioni')),
                      ],
                      rows: sponsors
                          .map(
                            (sponsor) =>
                                _buildSponsorTableRow(context, sponsor),
                          )
                          .toList(),
                    ),
                  ),
          ],
        );
      },
    );
  }

  Widget _buildUsersManagement(BuildContext context, bool isMobile) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Errore: ${snapshot.error}'));
        }

        final users = snapshot.data?.docs ?? [];

        if (users.isEmpty) {
          return const Center(child: Text('Nessun utente trovato'));
        }

        return Column(
          children: [
            Text(
              'Utenti registrati: ${users.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            isMobile
                ? ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final userDoc = users[index];
                      return _buildUserCard(context, userDoc);
                    },
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Data Registrazione')),
                        DataColumn(label: Text('Ruoli')),
                        DataColumn(label: Text('Azioni')),
                      ],
                      rows: users
                          .map(
                            (userDoc) => _buildUserTableRow(context, userDoc),
                          )
                          .toList(),
                    ),
                  ),
          ],
        );
      },
    );
  }

  Widget _buildBarCard(BuildContext context, BarSpot bar) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    bar.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: AppColors.ocean,
                        size: 20,
                      ),
                      onPressed: () => _showEditBarDialog(context, bar),
                      tooltip: 'Modifica',
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () => _deleteBar(context, bar.id),
                      tooltip: 'Elimina',
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Città', bar.city),
            _buildInfoRow('Indirizzo', bar.address),
            _buildInfoRow('Refill Info', bar.refillInfo),
            if (bar.featured)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.ocean.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '⭐ Featured',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.ocean,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  DataRow _buildBarTableRow(BuildContext context, BarSpot bar) {
    return DataRow(
      cells: [
        DataCell(Text(bar.name)),
        DataCell(Text(bar.city)),
        DataCell(Text(bar.address)),
        DataCell(Text(bar.refillInfo)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: AppColors.ocean),
                onPressed: () => _showEditBarDialog(context, bar),
                tooltip: 'Modifica',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteBar(context, bar.id),
                tooltip: 'Elimina',
              ),
            ],
          ),
        ),
      ],
    );
  }

  DataRow _buildSponsorTableRow(BuildContext context, SponsorSpot sponsor) {
    return DataRow(
      cells: [
        DataCell(Text(sponsor.name)),
        DataCell(Text(sponsor.category)),
        DataCell(Text(sponsor.address)),
        DataCell(Text(sponsor.featured ? '✓' : '-')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: AppColors.ocean),
                onPressed: () => _showEditSponsorDialog(context, sponsor),
                tooltip: 'Modifica',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteSponsor(context, sponsor.id),
                tooltip: 'Elimina',
              ),
            ],
          ),
        ),
      ],
    );
  }

  DataRow _buildUserTableRow(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> userDoc,
  ) {
    final data = userDoc.data();
    final email = data['email'] as String? ?? 'N/A';
    final status = data['status'] as String? ?? 'active';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final roles = (data['roles'] as List<dynamic>?)?.cast<String>() ?? [];

    return DataRow(
      cells: [
        DataCell(Text(email)),
        DataCell(Text(status)),
        DataCell(Text(createdAt?.toString().split('.')[0] ?? 'N/A')),
        DataCell(Text(roles.isEmpty ? 'user' : roles.join(', '))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, color: AppColors.ocean),
                onPressed: () => _showUserDetails(context, userDoc),
                tooltip: 'Dettagli',
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddBarDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _BarFormDialog(
        barService: _barService,
        onSave: (bar) {
          Navigator.pop(context);
          _addBar(bar);
        },
      ),
    );
  }

  void _showEditBarDialog(BuildContext context, BarSpot bar) {
    showDialog(
      context: context,
      builder: (context) => _BarFormDialog(
        barService: _barService,
        initialBar: bar,
        onSave: (updatedBar) {
          Navigator.pop(context);
          _updateBar(updatedBar);
        },
      ),
    );
  }

  Future<void> _addBar(BarSpot bar) async {
    try {
      final collection = FirebaseFirestore.instance.collection('bars');
      await collection.doc(bar.id).set(bar.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Locale aggiunto con successo')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _updateBar(BarSpot bar) async {
    try {
      final collection = FirebaseFirestore.instance.collection('bars');
      await collection.doc(bar.id).update(bar.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Locale aggiornato con successo')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _deleteBar(BuildContext context, String barId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: const Text('Sei sicuro di voler eliminare questo locale?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('bars').doc(barId).delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Locale eliminato con successo')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Errore: $e')));
        }
      }
    }
  }

  // ============ SPONSOR METHODS ============

  void _showAddSponsorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _SponsorFormDialog(
        onSave: (sponsor) {
          Navigator.pop(context);
          _addSponsor(sponsor);
        },
      ),
    );
  }

  void _showEditSponsorDialog(BuildContext context, SponsorSpot sponsor) {
    showDialog(
      context: context,
      builder: (context) => _SponsorFormDialog(
        initialSponsor: sponsor,
        onSave: (updatedSponsor) {
          Navigator.pop(context);
          _updateSponsor(updatedSponsor);
        },
      ),
    );
  }

  Future<void> _addSponsor(SponsorSpot sponsor) async {
    try {
      await FirebaseFirestore.instance
          .collection('sponsors')
          .doc(sponsor.id)
          .set(sponsor.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sponsor aggiunto con successo')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _updateSponsor(SponsorSpot sponsor) async {
    try {
      await FirebaseFirestore.instance
          .collection('sponsors')
          .doc(sponsor.id)
          .update(sponsor.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sponsor aggiornato con successo')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _deleteSponsor(BuildContext context, String sponsorId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: const Text('Sei sicuro di voler eliminare questo sponsor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('sponsors')
            .doc(sponsorId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sponsor eliminato con successo')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Errore: $e')));
        }
      }
    }
  }

  // ============ USERS METHODS ============

  void _showUserDetails(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> userDoc,
  ) {
    final data = userDoc.data();
    final email = data['email'] as String? ?? 'N/A';
    final status = data['status'] as String? ?? 'active';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final roles = (data['roles'] as List<dynamic>?)?.cast<String>() ?? [];
    final accountType = data['accountType'] as String? ?? 'user';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dettagli Utente'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Email: $email'),
              const SizedBox(height: 8),
              Text('Stato: $status'),
              const SizedBox(height: 8),
              Text('Tipo Account: $accountType'),
              const SizedBox(height: 8),
              Text(
                'Data Registrazione: ${createdAt?.toString().split('.')[0] ?? 'N/A'}',
              ),
              const SizedBox(height: 8),
              Text('Ruoli: ${roles.isEmpty ? 'user' : roles.join(', ')}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore logout: $e')));
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.deepOcean,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSponsorCard(BuildContext context, SponsorSpot sponsor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    sponsor.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: AppColors.ocean,
                        size: 20,
                      ),
                      onPressed: () => _showEditSponsorDialog(context, sponsor),
                      tooltip: 'Modifica',
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () => _deleteSponsor(context, sponsor.id),
                      tooltip: 'Elimina',
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Categoria', sponsor.category),
            _buildInfoRow('Indirizzo', sponsor.address),
            _buildInfoRow('Contributo', sponsor.contribution),
            if (sponsor.featured)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.ocean.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '⭐ Featured',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.ocean,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> userDoc,
  ) {
    final data = userDoc.data();
    final email = data['email'] as String? ?? 'N/A';
    final status = data['status'] as String? ?? 'active';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final roles = (data['roles'] as List<dynamic>?)?.cast<String>() ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    email,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.visibility,
                    color: AppColors.ocean,
                    size: 20,
                  ),
                  onPressed: () => _showUserDetails(context, userDoc),
                  tooltip: 'Dettagli',
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Status', status),
            _buildInfoRow(
              'Data Registrazione',
              createdAt?.toString().split('.')[0] ?? 'N/A',
            ),
            _buildInfoRow('Ruoli', roles.isEmpty ? 'user' : roles.join(', ')),
          ],
        ),
      ),
    );
  }
}

class _NewManagedUser {
  const _NewManagedUser({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    required this.role,
    required this.phone,
    required this.residence,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String role;
  final String phone;
  final String residence;
}

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog({required this.canAssignAdminRoles});

  final bool canAssignAdminRoles;

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _residence = TextEditingController();
  String _role = 'customer';

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _residence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roles = <(String, String)>[
      ('customer', 'Cliente'),
      ('refill_manager', 'Refill Manager'),
      ('sponsor_manager', 'Sponsor Manager'),
      if (widget.canAssignAdminRoles) ...[
        ('admin', 'Admin'),
        ('super_admin', 'Super Admin'),
      ],
    ];

    return AlertDialog(
      title: const Text('Aggiungi utente'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_firstName, 'Nome'),
                _field(_lastName, 'Cognome'),
                _field(
                  _email,
                  'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                _field(
                  _password,
                  'Password (almeno 8 caratteri)',
                  obscureText: true,
                  validator: (value) => (value?.length ?? 0) < 8
                      ? 'Inserisci almeno 8 caratteri'
                      : null,
                ),
                _field(
                  _phone,
                  'Telefono',
                  required: false,
                  keyboardType: TextInputType.phone,
                ),
                _field(_residence, 'Residenza', required: false),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Ruolo'),
                  items: roles
                      .map(
                        (role) => DropdownMenuItem(
                          value: role.$1,
                          child: Text(role.$2),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _role = value ?? 'customer'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _NewManagedUser(
                firstName: _firstName.text.trim(),
                lastName: _lastName.text.trim(),
                email: _email.text.trim(),
                password: _password.text,
                role: _role,
                phone: _phone.text.trim(),
                residence: _residence.text.trim(),
              ),
            );
          },
          child: const Text('Crea utente'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator:
          validator ??
          (value) => required && (value?.trim().isEmpty ?? true)
              ? 'Campo obbligatorio'
              : null,
    );
  }
}

class _BarFormDialog extends StatefulWidget {
  final BarService barService;
  final BarSpot? initialBar;
  final Function(BarSpot) onSave;

  const _BarFormDialog({
    required this.barService,
    this.initialBar,
    required this.onSave,
  });

  @override
  State<_BarFormDialog> createState() => _BarFormDialogState();
}

class _BarFormDialogState extends State<_BarFormDialog> {
  static const Duration _addressSearchDelay = Duration(milliseconds: 450);

  late TextEditingController nameController;
  late TextEditingController addressController;
  late TextEditingController cityController;
  late TextEditingController latitudeController;
  late TextEditingController longitudeController;
  late TextEditingController postalCodeController;
  late TextEditingController refillInfoController;
  late TextEditingController openInfoController;
  late TextEditingController idController;

  late List<String> services;
  late Map<String, String> socialLinks;
  bool featured = false;
  Timer? _addressSearchDebounce;
  bool _isSearchingAddress = false;
  String? _addressSearchError;
  final AddressSearchService _addressSearchService = AddressSearchService();
  List<AddressSuggestion> _addressResults = [];
  AddressDetails? _selectedAddress;
  late String _addressSessionToken;

  @override
  void initState() {
    super.initState();
    final bar = widget.initialBar;

    nameController = TextEditingController(text: bar?.name ?? '');
    addressController = TextEditingController(text: bar?.address ?? '');
    addressController.addListener(_onAddressChanged);
    cityController = TextEditingController(text: bar?.city ?? '');
    latitudeController = TextEditingController(
      text: bar?.location.latitude.toString() ?? '',
    );
    longitudeController = TextEditingController(
      text: bar?.location.longitude.toString() ?? '',
    );
    postalCodeController = TextEditingController(text: bar?.postalCode ?? '');
    _addressSessionToken = _newAddressSessionToken();
    refillInfoController = TextEditingController(
      text: bar?.refillInfo ?? 'Punto refill',
    );
    openInfoController = TextEditingController(
      text: bar?.openInfo ?? 'Lun-Dom 08:00-23:00',
    );
    idController = TextEditingController(text: bar?.id ?? '');

    services = bar?.services.toList() ?? [];
    socialLinks = Map<String, String>.from(bar?.socialLinks ?? const {});
    featured = bar?.featured ?? false;
  }

  @override
  void dispose() {
    _addressSearchDebounce?.cancel();
    nameController.dispose();
    addressController.dispose();
    cityController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    postalCodeController.dispose();
    refillInfoController.dispose();
    openInfoController.dispose();
    idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialBar != null;

    return AlertDialog(
      title: Text(isEditing ? 'Modifica Locale' : 'Aggiungi Locale'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isEditing)
              _buildTextField(idController, 'ID Locale', 'Es: caffe-duomo'),
            _buildTextField(nameController, 'Nome', 'Es: Caffè del Duomo'),
            _buildAddressSearchField(),
            _buildTextField(
              cityController,
              'Città',
              'Es: Terracina',
              readOnly: true,
            ),
            _buildTextField(
              latitudeController,
              'Latitudine',
              'Es: 41.2916360',
              readOnly: true,
            ),
            _buildTextField(
              longitudeController,
              'Longitudine',
              'Es: 13.2485294',
              readOnly: true,
            ),
            _buildTextField(
              postalCodeController,
              'CAP',
              'Es: 04019',
              readOnly: true,
            ),
            _buildTextField(
              refillInfoController,
              'Info Refill',
              'Es: Refill verificato',
            ),
            _buildTextField(
              openInfoController,
              'Orari',
              'Es: Lun-Dom 07:00-23:30',
            ),
            if (services.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: services
                      .map((service) => Chip(label: Text(service)))
                      .toList(),
                ),
              ),
            ],
            if (socialLinks['website']?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Sito web importato',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  child: SelectableText(socialLinks['website']!),
                ),
              ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Featured'),
              value: featured,
              onChanged: (value) => setState(() => featured = value ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _saveBar,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.ocean),
          child: const Text('Salva'),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildAddressSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: addressController,
            decoration: InputDecoration(
              labelText: 'Cerca locale o indirizzo',
              hintText: 'Es: Bar Centrale Fondi oppure Via Roma 15',
              helperText: 'Seleziona un risultato per compilare la scheda.',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearchingAddress
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _selectedAddress != null
                  ? const Icon(Icons.check_circle, color: AppColors.ocean)
                  : null,
            ),
          ),
          if (_addressSearchError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _addressSearchError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          if (_addressResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _addressResults.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: Colors.grey.shade300),
                itemBuilder: (context, index) {
                  final result = _addressResults[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place, color: AppColors.ocean),
                    title: Text(result.label),
                    subtitle: Text(result.secondaryText),
                    onTap: () => _selectAddressResult(result),
                  );
                },
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => launchUrl(
                Uri.parse('https://www.geoapify.com/'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text(
                'Powered by Geoapify',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onAddressChanged() {
    final query = addressController.text.trim();

    if (_selectedAddress?.formattedAddress == query) {
      return;
    }

    _selectedAddress = null;
    cityController.clear();
    latitudeController.clear();
    longitudeController.clear();
    postalCodeController.clear();

    _addressSearchDebounce?.cancel();
    if (query.length < 4) {
      if (mounted) {
        setState(() {
          _addressResults = [];
          _addressSearchError = null;
          _isSearchingAddress = false;
        });
      }
      return;
    }

    _addressSearchDebounce = Timer(
      _addressSearchDelay,
      () => _searchAddress(query),
    );
  }

  Future<void> _searchAddress(String query) async {
    if (!mounted) return;

    setState(() {
      _isSearchingAddress = true;
      _addressSearchError = null;
    });

    try {
      final results = await _addressSearchService.autocomplete(
        query: query,
        sessionToken: _addressSessionToken,
      );

      if (!mounted || addressController.text.trim() != query) return;

      setState(() {
        _addressResults = results;
        _addressSearchError = results.isEmpty
            ? 'Nessun indirizzo trovato.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addressResults = [];
        _addressSearchError = 'Impossibile cercare l indirizzo ora.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSearchingAddress = false);
      }
    }
  }

  Future<void> _selectAddressResult(AddressSuggestion result) async {
    _addressSearchDebounce?.cancel();
    setState(() {
      _addressResults = [];
      _addressSearchError = null;
      _isSearchingAddress = true;
    });

    try {
      final details = await _addressSearchService.details(
        placeId: result.placeId,
        sessionToken: _addressSessionToken,
      );
      if (!mounted) return;
      addressController
        ..removeListener(_onAddressChanged)
        ..text = details.formattedAddress
        ..selection = TextSelection.collapsed(
          offset: details.formattedAddress.length,
        )
        ..addListener(_onAddressChanged);

      setState(() {
        _selectedAddress = details;
        if (details.name.isNotEmpty) {
          nameController.text = details.name;
          if (widget.initialBar == null) {
            idController.text = _slugify(details.name);
          }
        }
        cityController.text = details.city;
        postalCodeController.text = details.postalCode;
        latitudeController.text = details.latitude.toStringAsFixed(7);
        longitudeController.text = details.longitude.toStringAsFixed(7);
        if (details.openingHours.isNotEmpty) {
          openInfoController.text = details.openingHours;
        }
        services = {...services, ...details.services}.toList();
        if (details.website.isNotEmpty) {
          socialLinks['website'] = details.website;
        }
        _addressSessionToken = _newAddressSessionToken();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addressSearchError =
            'Impossibile recuperare i dettagli dell indirizzo.';
      });
    } finally {
      if (mounted) setState(() => _isSearchingAddress = false);
    }
  }

  void _saveBar() {
    try {
      final id =
          widget.initialBar?.id ?? idController.text.toLowerCase().trim();

      if (id.isEmpty) {
        throw Exception('ID locale è obbligatorio');
      }

      final address = addressController.text.trim();
      final isExistingAddress =
          widget.initialBar != null && widget.initialBar?.address == address;
      if (_selectedAddress == null && !isExistingAddress) {
        throw Exception('seleziona un indirizzo dai risultati di ricerca');
      }

      final lat = double.parse(latitudeController.text);
      final lng = double.parse(longitudeController.text);

      final bar = BarSpot(
        id: id,
        name: nameController.text.trim(),
        address: address,
        city: cityController.text.trim(),
        location: LatLng(lat, lng),
        refillInfo: refillInfoController.text.trim(),
        openInfo: openInfoController.text.trim(),
        services: services,
        socialLinks: socialLinks,
        galleryImages: widget.initialBar?.galleryImages ?? [],
        featured: featured,
        postalCode:
            _selectedAddress?.postalCode ?? widget.initialBar?.postalCode ?? '',
        googlePlaceId:
            _selectedAddress?.placeId ?? widget.initialBar?.googlePlaceId ?? '',
      );

      widget.onSave(bar);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }
}

String _slugify(String value) {
  const accented = 'àáâäãåèéêëìíîïòóôöõùúûüçñ';
  const plain = 'aaaaaaeeeeiiiiooooouuuucn';
  var normalized = value.toLowerCase();
  for (var index = 0; index < accented.length; index++) {
    normalized = normalized.replaceAll(accented[index], plain[index]);
  }
  return normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

String _newAddressSessionToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

class _SponsorFormDialog extends StatefulWidget {
  final SponsorSpot? initialSponsor;
  final Function(SponsorSpot) onSave;

  const _SponsorFormDialog({this.initialSponsor, required this.onSave});

  @override
  State<_SponsorFormDialog> createState() => _SponsorFormDialogState();
}

class _SponsorFormDialogState extends State<_SponsorFormDialog> {
  late TextEditingController idController;
  late TextEditingController nameController;
  late TextEditingController categoryController;
  late TextEditingController addressController;
  late TextEditingController contributionController;
  late TextEditingController thankYouMessageController;

  bool featured = false;

  @override
  void initState() {
    super.initState();
    final sponsor = widget.initialSponsor;

    idController = TextEditingController(text: sponsor?.id ?? '');
    nameController = TextEditingController(text: sponsor?.name ?? '');
    categoryController = TextEditingController(text: sponsor?.category ?? '');
    addressController = TextEditingController(text: sponsor?.address ?? '');
    contributionController = TextEditingController(
      text: sponsor?.contribution ?? '',
    );
    thankYouMessageController = TextEditingController(
      text: sponsor?.thankYouMessage ?? '',
    );
    featured = sponsor?.featured ?? false;
  }

  @override
  void dispose() {
    idController.dispose();
    nameController.dispose();
    categoryController.dispose();
    addressController.dispose();
    contributionController.dispose();
    thankYouMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialSponsor != null;

    return AlertDialog(
      title: Text(isEditing ? 'Modifica Sponsor' : 'Aggiungi Sponsor'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isEditing)
              _buildTextField(idController, 'ID Sponsor', 'Es: emporio-corso'),
            _buildTextField(nameController, 'Nome', 'Es: Emporio del Corso'),
            _buildTextField(categoryController, 'Categoria', 'Es: Market'),
            _buildTextField(
              addressController,
              'Indirizzo',
              'Es: Corso Italia 18',
            ),
            _buildTextField(
              contributionController,
              'Contributo',
              'Es: Supporto materiali',
            ),
            _buildTextField(
              thankYouMessageController,
              'Messaggio di Ringraziamento',
              'Es: Grazie per il supporto',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Featured'),
              value: featured,
              onChanged: (value) => setState(() => featured = value ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _saveSponsor,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.ocean),
          child: const Text('Salva'),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  void _saveSponsor() {
    try {
      final id =
          widget.initialSponsor?.id ?? idController.text.toLowerCase().trim();

      if (id.isEmpty) {
        throw Exception('ID sponsor è obbligatorio');
      }

      final sponsor = SponsorSpot(
        id: id,
        name: nameController.text.trim(),
        category: categoryController.text.trim(),
        address: addressController.text.trim(),
        contribution: contributionController.text.trim(),
        thankYouMessage: thankYouMessageController.text.trim(),
        supports: widget.initialSponsor?.supports ?? [],
        socialLinks: widget.initialSponsor?.socialLinks ?? {},
        featured: featured,
      );

      widget.onSave(sponsor);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }
}
