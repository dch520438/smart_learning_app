import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// 特殊符号选择器组件
/// 支持数学符号、物理符号、化学符号、单位符号、标点符号和常用公式模板
class SymbolPickerWidget extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;

  const SymbolPickerWidget({
    super.key,
    required this.controller,
    this.focusNode,
  });

  @override
  State<SymbolPickerWidget> createState() => _SymbolPickerWidgetState();
}

class _SymbolPickerWidgetState extends State<SymbolPickerWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 符号分类
  static const List<String> _categories = [
    '数学',
    '物理',
    '化学',
    '单位',
    '标点',
    '公式',
  ];

  // 数学符号
  static const List<Map<String, String>> _mathSymbols = [
    {'symbol': '+', 'name': '加号'},
    {'symbol': '-', 'name': '减号'},
    {'symbol': '×', 'name': '乘号'},
    {'symbol': '÷', 'name': '除号'},
    {'symbol': '=', 'name': '等号'},
    {'symbol': '≠', 'name': '不等号'},
    {'symbol': '≈', 'name': '约等号'},
    {'symbol': '≡', 'name': '恒等号'},
    {'symbol': '<', 'name': '小于'},
    {'symbol': '>', 'name': '大于'},
    {'symbol': '≤', 'name': '小于等于'},
    {'symbol': '≥', 'name': '大于等于'},
    {'symbol': '±', 'name': '正负号'},
    {'symbol': '∓', 'name': '负正号'},
    {'symbol': '√', 'name': '根号'},
    {'symbol': '∛', 'name': '立方根'},
    {'symbol': '∜', 'name': '四次根'},
    {'symbol': '∞', 'name': '无穷'},
    {'symbol': '∑', 'name': '求和'},
    {'symbol': '∏', 'name': '求积'},
    {'symbol': '∫', 'name': '积分'},
    {'symbol': '∬', 'name': '二重积分'},
    {'symbol': '∮', 'name': '环路积分'},
    {'symbol': '∂', 'name': '偏导'},
    {'symbol': '∇', 'name': '梯度'},
    {'symbol': 'π', 'name': '圆周率'},
    {'symbol': 'e', 'name': '自然常数'},
    {'symbol': 'φ', 'name': '黄金比例'},
    {'symbol': 'i', 'name': '虚数单位'},
    {'symbol': '°', 'name': '度'},
    {'symbol': '′', 'name': '分'},
    {'symbol': '″', 'name': '秒'},
    {'symbol': '⊥', 'name': '垂直'},
    {'symbol': '∥', 'name': '平行'},
    {'symbol': '∠', 'name': '角'},
    {'symbol': '△', 'name': '三角形'},
    {'symbol': '□', 'name': '正方形'},
    {'symbol': '○', 'name': '圆'},
    {'symbol': '∪', 'name': '并集'},
    {'symbol': '∩', 'name': '交集'},
    {'symbol': '∈', 'name': '属于'},
    {'symbol': '∉', 'name': '不属于'},
    {'symbol': '⊂', 'name': '真子集'},
    {'symbol': '⊆', 'name': '子集'},
    {'symbol': '∅', 'name': '空集'},
    {'symbol': '∀', 'name': '任意'},
    {'symbol': '∃', 'name': '存在'},
    {'symbol': '¬', 'name': '非'},
    {'symbol': '∧', 'name': '与'},
    {'symbol': '∨', 'name': '或'},
    {'symbol': '⇒', 'name': '推出'},
    {'symbol': '⇔', 'name': '等价'},
    {'symbol': '→', 'name': '箭头'},
    {'symbol': '←', 'name': '反向箭头'},
    {'symbol': '↔', 'name': '双向箭头'},
  ];

  // 物理符号
  static const List<Map<String, String>> _physicsSymbols = [
    {'symbol': 'α', 'name': 'alpha/角加速度'},
    {'symbol': 'β', 'name': 'beta'},
    {'symbol': 'γ', 'name': 'gamma'},
    {'symbol': 'δ', 'name': 'delta'},
    {'symbol': 'ε', 'name': 'epsilon/介电常数'},
    {'symbol': 'ζ', 'name': 'zeta'},
    {'symbol': 'η', 'name': 'eta/效率'},
    {'symbol': 'θ', 'name': 'theta/角度'},
    {'symbol': 'ι', 'name': 'iota'},
    {'symbol': 'κ', 'name': 'kappa'},
    {'symbol': 'λ', 'name': 'lambda/波长'},
    {'symbol': 'μ', 'name': 'mu/微/摩擦系数'},
    {'symbol': 'ν', 'name': 'nu/频率'},
    {'symbol': 'ξ', 'name': 'xi'},
    {'symbol': 'π', 'name': 'pi/圆周率'},
    {'symbol': 'ρ', 'name': 'rho/密度'},
    {'symbol': 'σ', 'name': 'sigma/应力'},
    {'symbol': 'τ', 'name': 'tau/力矩'},
    {'symbol': 'υ', 'name': 'upsilon'},
    {'symbol': 'φ', 'name': 'phi/电势'},
    {'symbol': 'χ', 'name': 'chi'},
    {'symbol': 'ψ', 'name': 'psi'},
    {'symbol': 'ω', 'name': 'omega/角速度'},
    {'symbol': 'Ω', 'name': 'Omega/电阻'},
    {'symbol': 'Δ', 'name': 'Delta/变化量'},
    {'symbol': 'Φ', 'name': 'Phi/磁通量'},
    {'symbol': 'Ψ', 'name': 'Psi'},
    {'symbol': 'c', 'name': '光速'},
    {'symbol': 'h', 'name': '普朗克常数'},
    {'symbol': 'F', 'name': '力'},
    {'symbol': 'E', 'name': '能量/电场'},
    {'symbol': 'P', 'name': '功率/动量'},
    {'symbol': 'V', 'name': '电压/体积'},
    {'symbol': 'I', 'name': '电流'},
    {'symbol': 'R', 'name': '电阻'},
    {'symbol': 'Q', 'name': '热量/电荷'},
    {'symbol': 'T', 'name': '温度/周期'},
    {'symbol': 'm', 'name': '质量'},
    {'symbol': 'v', 'name': '速度'},
    {'symbol': 'a', 'name': '加速度'},
    {'symbol': 'g', 'name': '重力加速度'},
  ];

  // 化学符号
  static const List<Map<String, String>> _chemistrySymbols = [
    {'symbol': '→', 'name': '反应生成'},
    {'symbol': '⇌', 'name': '可逆反应'},
    {'symbol': '↑', 'name': '气体上升'},
    {'symbol': '↓', 'name': '沉淀下降'},
    {'symbol': '△', 'name': '加热'},
    {'symbol': '°C', 'name': '摄氏度'},
    {'symbol': 'K', 'name': '开尔文'},
    {'symbol': 'mol', 'name': '摩尔'},
    {'symbol': 'M', 'name': '摩尔浓度'},
    {'symbol': 'pH', 'name': 'pH值'},
    {'symbol': 'H⁺', 'name': '氢离子'},
    {'symbol': 'OH⁻', 'name': '氢氧根'},
    {'symbol': 'H₂O', 'name': '水'},
    {'symbol': 'CO₂', 'name': '二氧化碳'},
    {'symbol': 'O₂', 'name': '氧气'},
    {'symbol': 'N₂', 'name': '氮气'},
    {'symbol': 'H₂', 'name': '氢气'},
    {'symbol': 'CH₄', 'name': '甲烷'},
    {'symbol': 'C₂H₅OH', 'name': '乙醇'},
    {'symbol': 'NaCl', 'name': '氯化钠'},
    {'symbol': 'HCl', 'name': '盐酸'},
    {'symbol': 'H₂SO₄', 'name': '硫酸'},
    {'symbol': 'HNO₃', 'name': '硝酸'},
    {'symbol': 'NaOH', 'name': '氢氧化钠'},
    {'symbol': 'CaCO₃', 'name': '碳酸钙'},
    {'symbol': 'Fe', 'name': '铁'},
    {'symbol': 'Cu', 'name': '铜'},
    {'symbol': 'Al', 'name': '铝'},
    {'symbol': 'Zn', 'name': '锌'},
    {'symbol': 'Ag', 'name': '银'},
    {'symbol': '⁺', 'name': '正电荷'},
    {'symbol': '⁻', 'name': '负电荷'},
    {'symbol': '¹', 'name': '上标1'},
    {'symbol': '²', 'name': '上标2'},
    {'symbol': '³', 'name': '上标3'},
    {'symbol': '⁴', 'name': '上标4'},
    {'symbol': '⁵', 'name': '上标5'},
    {'symbol': '⁶', 'name': '上标6'},
    {'symbol': '⁷', 'name': '上标7'},
    {'symbol': '⁸', 'name': '上标8'},
    {'symbol': '⁹', 'name': '上标9'},
    {'symbol': '⁰', 'name': '上标0'},
    {'symbol': '₁', 'name': '下标1'},
    {'symbol': '₂', 'name': '下标2'},
    {'symbol': '₃', 'name': '下标3'},
    {'symbol': '₄', 'name': '下标4'},
    {'symbol': '₅', 'name': '下标5'},
    {'symbol': '₆', 'name': '下标6'},
    {'symbol': '₇', 'name': '下标7'},
    {'symbol': '₈', 'name': '下标8'},
    {'symbol': '₉', 'name': '下标9'},
    {'symbol': '₀', 'name': '下标0'},
  ];

  // 单位符号
  static const List<Map<String, String>> _unitSymbols = [
    {'symbol': 'm', 'name': '米'},
    {'symbol': 'cm', 'name': '厘米'},
    {'symbol': 'mm', 'name': '毫米'},
    {'symbol': 'km', 'name': '千米'},
    {'symbol': 'nm', 'name': '纳米'},
    {'symbol': 'μm', 'name': '微米'},
    {'symbol': 'g', 'name': '克'},
    {'symbol': 'kg', 'name': '千克'},
    {'symbol': 'mg', 'name': '毫克'},
    {'symbol': 't', 'name': '吨'},
    {'symbol': 'L', 'name': '升'},
    {'symbol': 'mL', 'name': '毫升'},
    {'symbol': 's', 'name': '秒'},
    {'symbol': 'min', 'name': '分钟'},
    {'symbol': 'h', 'name': '小时'},
    {'symbol': 'Hz', 'name': '赫兹'},
    {'symbol': 'kHz', 'name': '千赫'},
    {'symbol': 'MHz', 'name': '兆赫'},
    {'symbol': 'N', 'name': '牛顿'},
    {'symbol': 'J', 'name': '焦耳'},
    {'symbol': 'kJ', 'name': '千焦'},
    {'symbol': 'W', 'name': '瓦特'},
    {'symbol': 'kW', 'name': '千瓦'},
    {'symbol': 'V', 'name': '伏特'},
    {'symbol': 'kV', 'name': '千伏'},
    {'symbol': 'A', 'name': '安培'},
    {'symbol': 'mA', 'name': '毫安'},
    {'symbol': 'Ω', 'name': '欧姆'},
    {'symbol': 'kΩ', 'name': '千欧'},
    {'symbol': 'F', 'name': '法拉'},
    {'symbol': 'μF', 'name': '微法'},
    {'symbol': 'Pa', 'name': '帕斯卡'},
    {'symbol': 'kPa', 'name': '千帕'},
    {'symbol': 'atm', 'name': '标准大气压'},
    {'symbol': 'T', 'name': '特斯拉'},
    {'symbol': 'Wb', 'name': '韦伯'},
    {'symbol': 'lm', 'name': '流明'},
    {'symbol': 'lx', 'name': '勒克斯'},
    {'symbol': 'dB', 'name': '分贝'},
    {'symbol': '°C', 'name': '摄氏度'},
    {'symbol': 'K', 'name': '开尔文'},
    {'symbol': 'mol', 'name': '摩尔'},
    {'symbol': 'cd', 'name': '坎德拉'},
    {'symbol': 'rad', 'name': '弧度'},
    {'symbol': 'sr', 'name': '球面度'},
    {'symbol': 'eV', 'name': '电子伏特'},
    {'symbol': 'u', 'name': '原子质量单位'},
    {'symbol': 'AU', 'name': '天文单位'},
    {'symbol': 'ly', 'name': '光年'},
    {'symbol': 'pc', 'name': '秒差距'},
  ];

  // 标点符号
  static const List<Map<String, String>> _punctuationSymbols = [
    {'symbol': '，', 'name': '逗号'},
    {'symbol': '。', 'name': '句号'},
    {'symbol': '、', 'name': '顿号'},
    {'symbol': '；', 'name': '分号'},
    {'symbol': '：', 'name': '冒号'},
    {'symbol': '？', 'name': '问号'},
    {'symbol': '！', 'name': '感叹号'},
    {'symbol': '"', 'name': '双引号'},
    {'symbol': '"', 'name': '左双引号'},
    {'symbol': '"', 'name': '右双引号'},
    {'symbol': ''', 'name': '单引号'},
    {'symbol': ''', 'name': '左单引号'},
    {'symbol': '\u2019', 'name': '右单引号'},
    {'symbol': '（', 'name': '左圆括号'},
    {'symbol': '）', 'name': '右圆括号'},
    {'symbol': '【', 'name': '左方括号'},
    {'symbol': '】', 'name': '右方括号'},
    {'symbol': '｛', 'name': '左花括号'},
    {'symbol': '｝', 'name': '右花括号'},
    {'symbol': '《', 'name': '左书名号'},
    {'symbol': '》', 'name': '右书名号'},
    {'symbol': '〈', 'name': '左单书名号'},
    {'symbol': '〉', 'name': '右单书名号'},
    {'symbol': '—', 'name': '破折号'},
    {'symbol': '…', 'name': '省略号'},
    {'symbol': '·', 'name': '间隔号'},
    {'symbol': '～', 'name': '波浪号'},
    {'symbol': '￥', 'name': '人民币'},
    {'symbol': '\$', 'name': '美元'},
    {'symbol': '€', 'name': '欧元'},
    {'symbol': '£', 'name': '英镑'},
    {'symbol': '¥', 'name': '日元'},
    {'symbol': '%', 'name': '百分号'},
    {'symbol': '‰', 'name': '千分号'},
    {'symbol': '°', 'name': '度'},
    {'symbol': '′', 'name': '分'},
    {'symbol': '″', 'name': '秒'},
    {'symbol': '№', 'name': '序号'},
    {'symbol': '§', 'name': '章节号'},
    {'symbol': '※', 'name': '注释号'},
    {'symbol': '☆', 'name': '空心星'},
    {'symbol': '★', 'name': '实心星'},
    {'symbol': '○', 'name': '空心圆'},
    {'symbol': '●', 'name': '实心圆'},
    {'symbol': '△', 'name': '空心三角'},
    {'symbol': '▲', 'name': '实心三角'},
    {'symbol': '□', 'name': '空心方块'},
    {'symbol': '■', 'name': '实心方块'},
    {'symbol': '◇', 'name': '空心菱形'},
    {'symbol': '◆', 'name': '实心菱形'},
  ];

  // 常用公式模板
  static const List<Map<String, String>> _formulaTemplates = [
    {'symbol': 'a²', 'name': '平方'},
    {'symbol': 'a³', 'name': '立方'},
    {'symbol': 'aⁿ', 'name': 'n次幂'},
    {'symbol': '√a', 'name': '平方根'},
    {'symbol': 'ⁿ√a', 'name': 'n次根'},
    {'symbol': 'a/b', 'name': '分数'},
    {'symbol': 'logₐb', 'name': '对数'},
    {'symbol': 'ln a', 'name': '自然对数'},
    {'symbol': 'sin θ', 'name': '正弦'},
    {'symbol': 'cos θ', 'name': '余弦'},
    {'symbol': 'tan θ', 'name': '正切'},
    {'symbol': 'cot θ', 'name': '余切'},
    {'symbol': 'sec θ', 'name': '正割'},
    {'symbol': 'csc θ', 'name': '余割'},
    {'symbol': 'arcsin x', 'name': '反正弦'},
    {'symbol': 'arccos x', 'name': '反余弦'},
    {'symbol': 'arctan x', 'name': '反正切'},
    {'symbol': 'lim', 'name': '极限'},
    {'symbol': 'd/dx', 'name': '导数'},
    {'symbol': '∂/∂x', 'name': '偏导'},
    {'symbol': '∫f(x)dx', 'name': '不定积分'},
    {'symbol': '∫ₐᵇf(x)dx', 'name': '定积分'},
    {'symbol': '∑ᵢ₌₁ⁿ', 'name': '求和'},
    {'symbol': '∏ᵢ₌₁ⁿ', 'name': '求积'},
    {'symbol': 'x₁', 'name': '下标'},
    {'symbol': 'x₂', 'name': '下标2'},
    {'symbol': 'xₙ', 'name': '下标n'},
    {'symbol': 'f(x)', 'name': '函数'},
    {'symbol': 'f⁻¹(x)', 'name': '反函数'},
    {'symbol': 'y\'', 'name': '导数符号'},
    {'symbol': 'y\'\'', 'name': '二阶导'},
    {'symbol': 'Δx', 'name': '增量'},
    {'symbol': '|x|', 'name': '绝对值'},
    {'symbol': '‖x‖', 'name': '范数'},
    {'symbol': 'x̄', 'name': '平均值'},
    {'symbol': 'x̂', 'name': '估计值'},
    {'symbol': 'x̃', 'name': '中位数'},
    {'symbol': '→', 'name': '箭头'},
    {'symbol': '⇒', 'name': '推出'},
    {'symbol': '⇔', 'name': '等价'},
    {'symbol': '∵', 'name': '因为'},
    {'symbol': '∴', 'name': '所以'},
    {'symbol': '∈', 'name': '属于'},
    {'symbol': '∉', 'name': '不属于'},
    {'symbol': '∀x', 'name': '任意x'},
    {'symbol': '∃x', 'name': '存在x'},
    {'symbol': '∅', 'name': '空集'},
    {'symbol': 'A∪B', 'name': '并集'},
    {'symbol': 'A∩B', 'name': '交集'},
    {'symbol': 'A⊆B', 'name': '子集'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _insertSymbol(String symbol) {
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;
    
    final start = selection.start >= 0 ? selection.start : 0;
    final end = selection.end >= 0 ? selection.end : text.length;
    
    final newText = text.substring(0, start) + symbol + text.substring(end);
    final newCursorPos = start + symbol.length;
    
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: newCursorPos);
    
    // 触发状态更新
    setState(() {});
  }

  List<Map<String, String>> _getSymbolsForCategory(int index) {
    switch (index) {
      case 0:
        return _mathSymbols;
      case 1:
        return _physicsSymbols;
      case 2:
        return _chemistrySymbols;
      case 3:
        return _unitSymbols;
      case 4:
        return _punctuationSymbols;
      case 5:
        return _formulaTemplates;
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 分类标签栏
          Container(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: theme.colorScheme.primary,
              labelStyle: TextStyle(
                fontSize: AppFontSize.sm,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: AppFontSize.sm,
                fontWeight: FontWeight.w400,
              ),
              tabAlignment: TabAlignment.start,
              dividerHeight: 0,
              tabs: _categories.map((cat) => Tab(text: cat)).toList(),
            ),
          ),
          // 符号网格
          SizedBox(
            height: 120,
            child: TabBarView(
              controller: _tabController,
              children: List.generate(_categories.length, (index) {
                final symbols = _getSymbolsForCategory(index);
                return _buildSymbolGrid(symbols, theme);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolGrid(List<Map<String, String>> symbols, ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1.2,
      ),
      itemCount: symbols.length,
      itemBuilder: (context, index) {
        final item = symbols[index];
        final symbol = item['symbol']!;
        
        return Tooltip(
          message: item['name'] ?? '',
          child: InkWell(
            onTap: () => _insertSymbol(symbol),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.divider.withOpacity(0.5),
                ),
              ),
              child: Center(
                child: Text(
                  symbol,
                  style: TextStyle(
                    fontSize: AppFontSize.md,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 简化版符号选择栏（用于空间有限的场景）
class CompactSymbolBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;

  const CompactSymbolBar({
    super.key,
    required this.controller,
    this.focusNode,
  });

  // 常用符号快捷栏
  static const List<String> _commonSymbols = [
    // 数学运算
    '+', '-', '×', '÷', '=', '≠', '≈', '<', '>', '≤', '≥',
    // 特殊数学符号
    '±', '√', '∞', '∑', '∫', 'π', '°',
    // 上下标
    '²', '³', 'ⁿ', '₁', '₂', 'ₙ',
    // 希腊字母
    'α', 'β', 'γ', 'δ', 'θ', 'λ', 'μ', 'σ', 'φ', 'ω',
    // 箭头和逻辑
    '→', '⇒', '⇔', '∈', '⊂', '∀', '∃',
    // 化学相关
    '↑', '↓', '⇌',
    // 标点
    '°C', '％', '‰',
  ];

  void _insertSymbol(BuildContext context, String symbol) {
    final text = controller.text;
    final selection = controller.selection;
    
    final start = selection.start >= 0 ? selection.start : 0;
    final end = selection.end >= 0 ? selection.end : text.length;
    
    final newText = text.substring(0, start) + symbol + text.substring(end);
    final newCursorPos = start + symbol.length;
    
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: newCursorPos);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: _commonSymbols.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final symbol = _commonSymbols[index];
          return InkWell(
            onTap: () => _insertSymbol(context, symbol),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.divider.withOpacity(0.5),
                ),
              ),
              child: Center(
                child: Text(
                  symbol,
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
