import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/api.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CreateDriverScreen extends StatefulWidget {
  const CreateDriverScreen({Key? key}) : super(key: key);

  @override
  _CreateDriverScreenState createState() => _CreateDriverScreenState();
}

class _CreateDriverScreenState extends State<CreateDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  // Datos del formulario
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  String _vehicleType = '4_ruedas';
  bool _isSpecial = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    _vehicleController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final driverService = DriverService();
      final result = await driverService.createDriver(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phoneNumber: _phoneNumberController.text,
        vehicle: _vehicleController.text,
        vehicleType: _vehicleType,
        pin: _pinController.text,
        isSpecial: _isSpecial,
      );

      if (!result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'No se pudo crear el conductor'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conductor creado correctamente')),
      );
      Navigator.pop(
        context,
        true,
      ); // Volver a la pantalla anterior con resultado exitoso
    } catch (error) {
      developer.log('Error en handleSubmit: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error al crear el conductor')),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Chofer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Información del Chofer',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Complete los datos para registrar un nuevo chofer',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Campo Nombre
                _buildInputField(
                  label: 'Nombre',
                  isRequired: true,
                  controller: _firstNameController,
                  icon: LucideIcons.user,
                  placeholder: 'Ingrese el nombre',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    return null;
                  },
                ),

                // Campo Apellidos
                _buildInputField(
                  label: 'Apellidos',
                  isRequired: true,
                  controller: _lastNameController,
                  icon: LucideIcons.user,
                  placeholder: 'Ingrese los apellidos',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Los apellidos son obligatorios';
                    }
                    return null;
                  },
                ),

                // Campo Teléfono
                _buildInputField(
                  label: 'Teléfono',
                  isRequired: true,
                  controller: _phoneNumberController,
                  icon: LucideIcons.phone,
                  placeholder: 'Ingrese el número de teléfono',
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El teléfono es obligatorio';
                    }
                    return null;
                  },
                ),

                // Campo PIN
                _buildInputField(
                  label: 'PIN',
                  isRequired: true,
                  controller: _pinController,
                  icon: LucideIcons.key,
                  placeholder: 'Ingrese el PIN de 4 dígitos',
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El PIN es obligatorio';
                    }
                    if (value.length < 4) {
                      return 'El PIN debe tener al menos 4 dígitos';
                    }
                    return null;
                  },
                ),

                // Campo Vehículo
                _buildInputField(
                  label: 'Vehículo',
                  controller: _vehicleController,
                  icon: LucideIcons.truck,
                  placeholder: 'Descripción del vehículo',
                ),

                // Tipo de Vehículo
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tipo de Vehículo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _buildVehicleTypeButton(
                            icon: LucideIcons.truck,
                            label: '4 Ruedas',
                            isSelected: _vehicleType == '4_ruedas',
                            onTap: () {
                              setState(() {
                                _vehicleType = '4_ruedas';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildVehicleTypeButton(
                            icon: LucideIcons.bike,
                            label: '2 Ruedas',
                            isSelected: _vehicleType == '2_ruedas',
                            onTap: () {
                              setState(() {
                                _vehicleType = '2_ruedas';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Conductor Especial
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Conductor Especial',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isSpecial = !_isSpecial;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.star,
                              size: 24,
                              color:
                                  _isSpecial
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Conductor Prioritario',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color:
                                    _isSpecial
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Botón de envío
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFFDC2626).withOpacity(0.15),
                    ),
                    onPressed: _loading ? null : _handleSubmit,
                    child:
                        _loading
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'Crear Chofer',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String placeholder,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF334155),
              ),
              children:
                  isRequired
                      ? const [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ]
                      : [],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 48,
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                    color: Color(0xFFF8FAFC),
                  ),
                  child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
                ),
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: placeholder,
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      counterText: '',
                    ),
                    keyboardType: keyboardType,
                    obscureText: obscureText,
                    maxLength: maxLength,
                    validator: validator,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTypeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
          ),
          color: isSelected ? const Color(0xFFFECACA) : Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
