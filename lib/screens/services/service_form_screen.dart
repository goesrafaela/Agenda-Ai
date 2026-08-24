import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';

class ServiceFormScreen extends StatefulWidget {
  const ServiceFormScreen({super.key});

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = SupabaseService.client.auth.currentUser;

    if (user == null) {
      _showMessage('Usuário não autenticado.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final price = double.tryParse(
        _priceController.text.trim().replaceAll(',', '.'),
      );

      final duration = int.tryParse(_durationController.text.trim());

      await SupabaseService.client.from('services').insert({
        'name': _nameController.text.trim(),
        'price': price ?? 0,
        'duration_minutes': duration ?? 0,
        'user_id': user.id,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serviço salvo com sucesso!')),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      _showMessage('Não foi possível salvar o serviço.');

      debugPrint('Erro ao salvar serviço: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo serviço')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Dados do serviço',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Text(
                  'Cadastre um serviço que você oferece.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),

                const SizedBox(height: 24),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome do serviço',
                    prefixIcon: Icon(Icons.work_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome do serviço';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Preço',
                    prefixIcon: Icon(Icons.attach_money),
                    prefixText: 'R\$ ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o preço';
                    }

                    final price = double.tryParse(
                      value.trim().replaceAll(',', '.'),
                    );

                    if (price == null || price < 0) {
                      return 'Informe um preço válido';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duração em minutos',
                    prefixIcon: Icon(Icons.timer_outlined),
                    suffixText: 'min',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe a duração';
                    }

                    final duration = int.tryParse(value.trim());

                    if (duration == null || duration <= 0) {
                      return 'Informe uma duração válida';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 24),

                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveService,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Salvando...' : 'Salvar serviço',
                      style: const TextStyle(fontSize: 16),
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
}
