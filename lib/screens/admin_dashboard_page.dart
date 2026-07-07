import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard Admin'),
          backgroundColor: AppColors.deepOcean,
          elevation: 0,
          bottom: TabBar(
            onTap: (index) => setState(() => _selectedTabIndex = index),
            tabs: const [
              Tab(icon: Icon(Icons.store), text: 'Locali'),
              Tab(icon: Icon(Icons.handshake), text: 'Sponsor'),
              Tab(icon: Icon(Icons.people), text: 'Utenti'),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  _authService.currentUser?.email ?? 'Non autenticato',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
              ),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildBarsTab(),
            _buildSponsorsTab(),
            _buildUsersTab(),
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

  Widget _buildBarsTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Gestione Locali',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.deepOcean,
              ),
            ),
            const SizedBox(height: 32),
            _buildBarsManagement(),
          ],
        ),
      ),
    );
  }

  Widget _buildSponsorsTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Gestione Sponsor',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.deepOcean,
              ),
            ),
            const SizedBox(height: 32),
            _buildSponsorsManagement(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Utenti Registrati',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.deepOcean,
              ),
            ),
            const SizedBox(height: 32),
            _buildUsersManagement(),
          ],
        ),
      ),
    );
  }

  Widget _buildBarsManagement() {
    return StreamBuilder<List<BarSpot>>(
      stream: _barService.watchBars(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Errore: ${snapshot.error}'),
          );
        }

        final bars = snapshot.data ?? [];

        if (bars.isEmpty) {
          return const Center(
            child: Text('Nessun locale trovato'),
          );
        }

        return Column(
          children: [
            Text(
              'Locali registrati: ${bars.length}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
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

  Widget _buildSponsorsManagement() {
    return StreamBuilder<List<SponsorSpot>>(
      stream: _sponsorService.watchSponsors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Errore: ${snapshot.error}'),
          );
        }

        final sponsors = snapshot.data ?? [];

        if (sponsors.isEmpty) {
          return const Center(
            child: Text('Nessuno sponsor trovato'),
          );
        }

        return Column(
          children: [
            Text(
              'Sponsor registrati: ${sponsors.length}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
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
                    .map((sponsor) => _buildSponsorTableRow(context, sponsor))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUsersManagement() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Errore: ${snapshot.error}'),
          );
        }

        final users = snapshot.data?.docs ?? [];

        if (users.isEmpty) {
          return const Center(
            child: Text('Nessun utente registrato'),
          );
        }

        return Column(
          children: [
            Text(
              'Utenti registrati: ${users.length}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Stato')),
                  DataColumn(label: Text('Data Registrazione')),
                  DataColumn(label: Text('Ruoli')),
                  DataColumn(label: Text('Azioni')),
                ],
                rows: users.map((userDoc) => _buildUserTableRow(context, userDoc)).toList(),
              ),
            ),
          ],
        );
      },
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

  DataRow _buildUserTableRow(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> userDoc) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
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
        await FirebaseFirestore.instance
            .collection('bars')
            .doc(barId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Locale eliminato con successo')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e')),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e')),
          );
        }
      }
    }
  }

  // ============ USERS METHODS ============

  void _showUserDetails(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> userDoc) {
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
              Text('Data Registrazione: ${createdAt?.toString().split('.')[0] ?? 'N/A'}'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore logout: $e')),
        );
      }
    }
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
  late TextEditingController nameController;
  late TextEditingController addressController;
  late TextEditingController cityController;
  late TextEditingController latitudeController;
  late TextEditingController longitudeController;
  late TextEditingController refillInfoController;
  late TextEditingController openInfoController;
  late TextEditingController idController;

  late List<String> services;
  bool featured = false;

  @override
  void initState() {
    super.initState();
    final bar = widget.initialBar;

    nameController = TextEditingController(text: bar?.name ?? '');
    addressController = TextEditingController(text: bar?.address ?? '');
    cityController = TextEditingController(text: bar?.city ?? '');
    latitudeController =
        TextEditingController(text: bar?.location.latitude.toString() ?? '');
    longitudeController =
        TextEditingController(text: bar?.location.longitude.toString() ?? '');
    refillInfoController =
        TextEditingController(text: bar?.refillInfo ?? 'Punto refill');
    openInfoController =
        TextEditingController(text: bar?.openInfo ?? 'Lun-Dom 08:00-23:00');
    idController = TextEditingController(text: bar?.id ?? '');

    services = bar?.services.toList() ?? [];
    featured = bar?.featured ?? false;
  }

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    cityController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
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
            _buildTextField(addressController, 'Indirizzo',
                'Es: Piazza Municipio 18'),
            _buildTextField(cityController, 'Città', 'Es: Terracina'),
            _buildTextField(
                latitudeController, 'Latitudine', 'Es: 41.2916360'),
            _buildTextField(
                longitudeController, 'Longitudine', 'Es: 13.2485294'),
            _buildTextField(refillInfoController, 'Info Refill',
                'Es: Refill verificato'),
            _buildTextField(
                openInfoController, 'Orari', 'Es: Lun-Dom 07:00-23:30'),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ocean,
          ),
          child: const Text('Salva'),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  void _saveBar() {
    try {
      final id =
          widget.initialBar?.id ?? idController.text.toLowerCase().trim();

      if (id.isEmpty) {
        throw Exception('ID locale è obbligatorio');
      }

      final lat = double.parse(latitudeController.text);
      final lng = double.parse(longitudeController.text);

      final bar = BarSpot(
        id: id,
        name: nameController.text.trim(),
        address: addressController.text.trim(),
        city: cityController.text.trim(),
        location: LatLng(lat, lng),
        refillInfo: refillInfoController.text.trim(),
        openInfo: openInfoController.text.trim(),
        services: services,
        socialLinks: widget.initialBar?.socialLinks ?? {},
        galleryImages: widget.initialBar?.galleryImages ?? [],
        featured: featured,
      );

      widget.onSave(bar);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }
}

class _SponsorFormDialog extends StatefulWidget {
  final SponsorSpot? initialSponsor;
  final Function(SponsorSpot) onSave;

  const _SponsorFormDialog({
    this.initialSponsor,
    required this.onSave,
  });

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
    contributionController = TextEditingController(text: sponsor?.contribution ?? '');
    thankYouMessageController = TextEditingController(text: sponsor?.thankYouMessage ?? '');
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
            _buildTextField(addressController, 'Indirizzo', 'Es: Corso Italia 18'),
            _buildTextField(contributionController, 'Contributo', 'Es: Supporto materiali'),
            _buildTextField(thankYouMessageController, 'Messaggio di Ringraziamento', 'Es: Grazie per il supporto', maxLines: 3),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ocean,
          ),
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
      final id = widget.initialSponsor?.id ?? idController.text.toLowerCase().trim();

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }
}
