import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:flutter/services.dart'; // Para input formatters
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

  // Controladores
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  // Estado del formulario
  String _vehicleType = '4_ruedas';
  bool _isSpecial = false;
  bool _obscurePin = true; // Para ocultar/mostrar PIN

  // Define colores para consistencia
  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red; // Iconos principales rojos
  final Color inputIconColor = Colors.grey.shade500; // Iconos dentro de inputs
  final Color errorColor = Colors.red.shade700;
  final Color successColor = Colors.green.shade600;
  final Color buttonTextColor = Colors.white;
  final Color borderColor = Colors.grey.shade300;

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
    // Ocultar teclado
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor corrija los errores en el formulario'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final driverService = DriverService();
      final result = await driverService.createDriver(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        vehicle: _vehicleController.text.trim(),
        vehicleType: _vehicleType,
        pin: _pinController.text.trim(),
        isSpecial: _isSpecial,
      );

      // Verificar si el widget sigue montado antes de interactuar con el contexto
      if (!mounted) return;

      if (!result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'No se pudo crear el conductor'),
            backgroundColor: errorColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Conductor creado correctamente'),
            backgroundColor: successColor,
          ),
        );
        Navigator.pop(context, true); // Volver con resultado exitoso
      }
    } catch (error) {
      developer.log('Error en handleSubmit: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ocurrió un error inesperado: $error'),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBackgroundColor,
        foregroundColor: textColorPrimary,
        elevation: 1.0,
        title: const Text(
          'Crear Nuevo Chofer',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          // Usar icono rojo consistente
          icon: Icon(Icons.arrow_back, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado (opcional, ya está en AppBar)
                // _buildHeader(),
                // const SizedBox(height: 16),

                // --- Campos del Formulario ---
                _buildSectionTitle('Información Personal'),
                _buildInputField(
                  label: 'Nombre(s)',
                  controller: _firstNameController,
                  icon: LucideIcons.user,
                  placeholder: 'Ingrese el nombre',
                  validator:
                      (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'El nombre es obligatorio'
                              : null,
                  textCapitalization: TextCapitalization.words,
                ),
                _buildInputField(
                  label: 'Apellidos',
                  controller: _lastNameController,
                  icon: LucideIcons.userCheck, // Icono diferente
                  placeholder: 'Ingrese los apellidos',
                  validator:
                      (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Los apellidos son obligatorios'
                              : null,
                  textCapitalization: TextCapitalization.words,
                ),
                _buildInputField(
                  label: 'Teléfono',
                  controller: _phoneNumberController,
                  icon: LucideIcons.phone,
                  placeholder: 'Ingrese el número de teléfono',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El teléfono es obligatorio';
                    }
                    if (value.length < 8) {
                      // Validación simple de longitud
                      return 'Ingrese un número de teléfono válido';
                    }
                    return null;
                  },
                ),
                _buildInputField(
                  label: 'PIN de Acceso',
                  controller: _pinController,
                  icon: LucideIcons.keyRound, // Icono diferente
                  placeholder: 'PIN de 4 a 6 dígitos',
                  keyboardType: TextInputType.number,
                  obscureText: _obscurePin,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePin ? LucideIcons.eyeOff : LucideIcons.eye,
                      color: textColorSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePin = !_obscurePin;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El PIN es obligatorio';
                    }
                    if (value.length < 4) {
                      return 'El PIN debe tener al menos 4 dígitos';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),
                _buildSectionTitle('Información del Vehículo'),
                _buildInputField(
                  label: 'Descripción del Vehículo',
                  controller: _vehicleController,
                  icon: LucideIcons.car, // Icono más genérico
                  placeholder: 'Ej: Nissan Tsuru Rojo Placas XXX-123',
                  // No obligatorio, sin validador
                  textCapitalization: TextCapitalization.sentences,
                ),

                // --- Tipo de Vehículo ---
                _buildLabel('Tipo de Vehículo'),
                Row(
                  children: [
                    Expanded(
                      child: _buildVehicleTypeButton(
                        icon: LucideIcons.car, // Icono consistente
                        label: '4 Ruedas',
                        value: '4_ruedas',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildVehicleTypeButton(
                        icon: LucideIcons.bike,
                        label: '2 Ruedas',
                        value: '2_ruedas',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // --- Conductor Especial ---
                _buildLabel('Prioridad'),
                _buildSpecialDriverToggle(),
                const SizedBox(height: 24), // Más espacio antes del botón
                // --- Botón de envío ---
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -- Widgets Reutilizables de Construcción --

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColorPrimary.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColorPrimary.withOpacity(0.9),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String placeholder,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    int? maxLength,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0), // Espaciado entre campos
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: textColorSecondary),
          hintText: placeholder,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, color: inputIconColor, size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: cardBackgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: errorColor, width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: errorColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 12,
          ),
          counterText: '', // Ocultar contador de maxLength por defecto
        ),
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLength: maxLength,
        validator: validator,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        style: TextStyle(fontSize: 15, color: textColorPrimary),
      ),
    );
  }

  Widget _buildVehicleTypeButton({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isSelected = _vehicleType == value;
    return Material(
      // Para efecto ripple
      color: isSelected ? primaryColor.withOpacity(0.1) : cardBackgroundColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          setState(() {
            _vehicleType = value;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? primaryColor : borderColor,
              width: isSelected ? 1.5 : 1.0,
            ),
            // El color de fondo se maneja en Material para el ripple
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20, // Icono más pequeño
                color: isSelected ? primaryColor : textColorSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? primaryColor : textColorSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialDriverToggle() {
    // Definimos un tamaño deseado para el botón cuadrado
    const double buttonSize = 52.0; // Puedes ajustar este valor

    return Material(
      // Para efecto ripple
      color: _isSpecial ? primaryColor.withOpacity(0.1) : cardBackgroundColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          setState(() {
            _isSpecial = !_isSpecial;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: buttonSize, // Ancho fijo
          height: buttonSize, // Alto fijo (para hacerlo cuadrado)
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isSpecial ? primaryColor : borderColor,
              width: _isSpecial ? 1.5 : 1.0,
            ),
            // El color de fondo se maneja en Material para el ripple
          ),
          // Usamos Stack para superponer el check sobre la estrella si es necesario
          // o simplemente centrar el icono principal
          child: Center(
            // Centra el icono principal
            child: Stack(
              // Stack para superponer el check
              alignment: Alignment.center,
              children: [
                // Icono principal (estrella) siempre visible
                Icon(
                  LucideIcons.star,
                  size: 24, // Tamaño del icono ajustado
                  color: _isSpecial ? primaryColor : textColorSecondary,
                ),
                // Icono de check (superpuesto y visible solo si _isSpecial es true)
                if (_isSpecial)
                  Positioned(
                    // Posiciona el check, por ejemplo, en la esquina
                    top: 4,
                    right: 4,
                    child: Icon(
                      Icons.check_circle,
                      color: primaryColor.withOpacity(0.9), // Un poco más sutil
                      size: 16, // Check más pequeño
                    ),
                  ),
                // Alternativa: Mostrar solo el check cuando está activo
                /*
                 Icon(
                   _isSpecial ? Icons.check_circle : LucideIcons.star,
                   size: 24,
                   color: _isSpecial ? primaryColor : textColorSecondary,
                 )
                 */
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon:
            _loading
                ? Container() // No mostrar icono si está cargando
                : Icon(LucideIcons.userPlus, size: 18, color: buttonTextColor),
        label:
            _loading
                ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: buttonTextColor,
                    strokeWidth: 2.5,
                  ),
                )
                : Text(
                  'Crear Chofer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: buttonTextColor,
                  ),
                ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: buttonTextColor, // Color del ripple
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2, // Sombra sutil
        ),
        onPressed: _loading ? null : _handleSubmit,
      ),
    );
  }
}
