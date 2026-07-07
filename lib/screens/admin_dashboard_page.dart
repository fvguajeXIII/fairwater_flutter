import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/bar_service.dart';
import '../theme/app_theme.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final BarService _barService = BarService();
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        backgroundColor: AppColors.deepOcean,
        elevation: 0,
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 32),
              _buildBarsManagement(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.ocean,
        onPressed: () => _showAddBarDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader() {
    return const Text(
      'Gestione Locali',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.deepOcean,
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
