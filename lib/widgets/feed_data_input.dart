import 'package:flutter/material.dart';
import '../models/journal_entry.dart';

/// Widget for inputting feed data information
class FeedDataInput extends StatefulWidget {
  final Function(FeedData?) onChanged;
  final FeedData? initialData;

  const FeedDataInput({
    Key? key,
    required this.onChanged,
    this.initialData,
  }) : super(key: key);

  @override
  State<FeedDataInput> createState() => _FeedDataInputState();
}

class _FeedDataInputState extends State<FeedDataInput> {
  final _brandController = TextEditingController();
  final _typeController = TextEditingController();
  final _amountController = TextEditingController();
  final _costController = TextEditingController();
  final _fcrController = TextEditingController();

  final List<String> _commonFeedBrands = [
    'Purina',
    'Nutrena',
    'Southern States',
    'MoorMan\'s',
    'Kent Nutrition',
    'Cargill',
    'ADM',
    'Other',
  ];

  final List<String> _feedTypes = [
    'Starter',
    'Grower',
    'Finisher',
    'Show Feed',
    'Maintenance',
    'Breeder',
    'Medicated',
    'Organic',
  ];

  String? _selectedBrand;
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _brandController.text = data.brand;
      _typeController.text = data.type;
      _amountController.text = data.amount.toString();
      _costController.text = data.cost.toString();
      if (data.feedConversionRatio != null) {
        _fcrController.text = data.feedConversionRatio.toString();
      }
      _selectedBrand = _commonFeedBrands.contains(data.brand) ? data.brand : 'Other';
      _selectedType = _feedTypes.contains(data.type) ? data.type : null;
    }
  }

  @override
  void dispose() {
    _brandController.dispose();
    _typeController.dispose();
    _amountController.dispose();
    _costController.dispose();
    _fcrController.dispose();
    super.dispose();
  }

  void _updateFeedData() {
    if (_isValid()) {
      final feedData = FeedData(
        brand: _selectedBrand == 'Other' ? _brandController.text : _selectedBrand!,
        type: _selectedType ?? _typeController.text,
        amount: double.parse(_amountController.text),
        cost: double.parse(_costController.text),
        feedConversionRatio: _fcrController.text.isNotEmpty 
            ? double.tryParse(_fcrController.text) 
            : null,
      );
      widget.onChanged(feedData);
    } else {
      widget.onChanged(null);
    }
  }

  bool _isValid() {
    return (_selectedBrand != null || _brandController.text.isNotEmpty) &&
           (_selectedType != null || _typeController.text.isNotEmpty) &&
           _amountController.text.isNotEmpty &&
           double.tryParse(_amountController.text) != null &&
           _costController.text.isNotEmpty &&
           double.tryParse(_costController.text) != null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Feed Brand
        const Text(
          'Feed Brand *',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedBrand,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          items: _commonFeedBrands.map((brand) {
            return DropdownMenuItem(
              value: brand,
              child: Text(brand),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedBrand = value;
            });
            _updateFeedData();
          },
        ),
        
        // Custom brand input (if "Other" is selected)
        if (_selectedBrand == 'Other') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _brandController,
            decoration: InputDecoration(
              labelText: 'Custom Brand Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (_) => _updateFeedData(),
          ),
        ],
        
        const SizedBox(height: 16),

        // Feed Type
        const Text(
          'Feed Type *',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedType,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          items: _feedTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedType = value;
            });
            _updateFeedData();
          },
        ),

        // Custom type input (if no predefined type is selected)
        if (_selectedType == null) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _typeController,
            decoration: InputDecoration(
              labelText: 'Custom Feed Type',
              hintText: 'e.g., Custom Mix, Pellets',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (_) => _updateFeedData(),
          ),
        ],

        const SizedBox(height: 16),

        // Amount and Cost Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Amount (lbs) *',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      hintText: '10.5',
                      suffixText: 'lbs',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _updateFeedData(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cost per lb *',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _costController,
                    decoration: InputDecoration(
                      hintText: '0.25',
                      prefixText: '\$',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _updateFeedData(),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Feed Conversion Ratio (Optional)
        const Text(
          'Feed Conversion Ratio',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        const Text(
          'Optional: lbs of feed per lb of weight gain',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _fcrController,
          decoration: InputDecoration(
            hintText: '3.5',
            suffixText: ':1',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _updateFeedData(),
        ),

        // Cost calculation display
        if (_amountController.text.isNotEmpty && 
            _costController.text.isNotEmpty &&
            double.tryParse(_amountController.text) != null &&
            double.tryParse(_costController.text) != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Feed Cost:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '\$${(double.parse(_amountController.text) * double.parse(_costController.text)).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D3A),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}