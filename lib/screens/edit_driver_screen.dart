import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:developer' as developer;
import '../services/api.dart';

class EditDriverScreen extends StatefulWidget {
  final DriverProfile? driver;

  const EditDriverScreen({Key? key, this.driver}) : super(key: key);

  @override
  _EditDriverScreenState createState() => _EditDriverScreenState();
}

class _EditDriverScreenState extends State<EditDriverScreen> {
  bool loading = false;
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos de texto
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController phoneNumberController;
  late TextEditingController vehicleController;
  late TextEditingController pinController;

  // Variables para los valores del formulario
  late String vehicleType;
  late bool isSpecial;

  @override
  void initState() {
    super.initState();

    // Inicializar controladores con los valores del conductor
    firstNameController = TextEditingController(
      text: widget.driver?.firstName ?? '',
    );
    lastNameController = TextEditingController(
      text: widget.driver?.lastName ?? '',
    );
    phoneNumberController = TextEditingController(
      text: widget.driver?.phoneNumber ?? '',
    );
    vehicleController = TextEditingController(
      text: widget.driver?.vehicle ?? '',
    );
    pinController = TextEditingController();

    // Inicializar otros valores
    vehicleType = widget.driver?.vehicleType ?? '4_ruedas';
    isSpecial = widget.driver?.isSpecial ?? false;
  }

  @override
  void dispose() {
    // Liberar recursos
    firstNameController.dispose();
    lastNameController.dispose();
    phoneNumberController.dispose();
    vehicleController.dispose();
    pinController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          loading = true;
        });

        // Preparar datos para actualización
        final Map<String, dynamic> formData = {
          'first_name': firstNameController.text,
          'last_name': lastNameController.text,
          'phone_number': phoneNumberController.text,
          'vehicle': vehicleController.text,
          'vehicle_type': vehicleType,
          'is_special': isSpecial,
        };

        // Añadir PIN solo si se ha ingresado uno nuevo
        if (pinController.text.isNotEmpty) {
          formData['pin'] = pinController.text;
        }

        final driverService = DriverService();
        await driverService.updateDriver(widget.driver!.id, formData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chofer actualizado correctamente')),
          );
          Navigator.pop(
            context,
            true,
          ); // Devolver true para indicar actualización exitosa
        }
      } catch (error) {
        developer.log('Error actualizando chofer: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo actualizar el Chofer')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            loading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Chofer')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado
                const Text(
                  'Editar Chofer',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Modifique los datos del Chofer',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),

                // Campo Nombre
                _buildInputLabel('Nombre', true),
                _buildInputField(
                  controller: firstNameController,
                  icon: LucideIcons.user,
                  hintText: 'Ingrese el nombre',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese el nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Campo Apellidos
                _buildInputLabel('Apellidos', true),
                _buildInputField(
                  controller: lastNameController,
                  icon: LucideIcons.user,
                  hintText: 'Ingrese los apellidos',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese los apellidos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Campo Teléfono
                _buildInputLabel('Teléfono', true),
                _buildInputField(
                  controller: phoneNumberController,
                  icon: LucideIcons.phone,
                  hintText: 'Ingrese el número de teléfono',
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese el teléfono';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Campo Vehículo
                _buildInputLabel('Vehículo', true),
                _buildInputField(
                  controller: vehicleController,
                  icon: LucideIcons.truck,
                  hintText: 'Descripción del vehículo',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese el vehículo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Campo PIN
                _buildInputLabel('PIN', false),
                _buildInputField(
                  controller: pinController,
                  icon: LucideIcons.keyRound,
                  hintText: 'Ingrese nuevo PIN (opcional)',
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                ),
                const SizedBox(height: 12),

                // Selector de Tipo de Vehículo
                _buildInputLabel('Tipo de Vehículo', false),
                Row(
                  children: [
                    Expanded(
                      child: _buildVehicleTypeButton(
                        icon: LucideIcons.truck,
                        label: '4 Ruedas',
                        isSelected: vehicleType == '4_ruedas',
                        onTap: () {
                          setState(() {
                            vehicleType = '4_ruedas';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildVehicleTypeButton(
                        icon: LucideIcons.bike,
                        label: '2 Ruedas',
                        isSelected: vehicleType == '2_ruedas',
                        onTap: () {
                          setState(() {
                            vehicleType = '2_ruedas';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Opción de Conductor Especial
                _buildInputLabel('Conductor Especial', false),
                _buildSpecialDriverButton(),
                const SizedBox(height: 20),

                // Botón de Actualizar
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: loading ? null : _handleUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4,
                    ),
                    child:
                        loading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'Actualizar Chofer',
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

  Widget _buildInputLabel(String label, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF334155),
            ),
          ),
          if (required)
            const Text(' *', style: TextStyle(color: Color(0xFFEF4444))),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                counterText: '',
              ),
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
              keyboardType: keyboardType,
              obscureText: obscureText,
              maxLength: maxLength,
              validator: validator,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFECACA) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
          ),
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

  Widget _buildSpecialDriverButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          isSpecial = !isSpecial;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.star,
              size: 24,
              color:
                  isSpecial ? const Color(0xFFDC2626) : const Color(0xFF64748B),
              fill: isSpecial ? 1.0 : 0.0,
            ),
            const SizedBox(width: 8),
            Text(
              'Conductor Prioritario',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color:
                    isSpecial
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
