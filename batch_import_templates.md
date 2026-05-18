# 批量导入模板

本文档提供各类型数据的批量导入模板，支持 JSON 和 CSV 两种格式。

## 一、知识点批量导入模板

### JSON 格式

```json
[
  {
    "title": "二次函数的定义",
    "content": "形如 y = ax² + bx + c (a≠0) 的函数称为二次函数",
    "subject": "数学",
    "chapter": "函数",
    "difficulty": 2,
    "importance": 3,
    "tags": ["函数", "二次函数", "定义"]
  },
  {
    "title": "牛顿第一定律",
    "content": "一切物体在没有受到力的作用时，总保持静止状态或匀速直线运动状态",
    "subject": "物理",
    "chapter": "力学",
    "difficulty": 3,
    "importance": 5,
    "tags": ["牛顿定律", "惯性", "力学"]
  }
]
```

### CSV 格式

```csv
title,content,subject,chapter,difficulty,importance,tags
二次函数的定义,形如 y = ax² + bx + c (a≠0) 的函数称为二次函数,数学,函数,2,3,"函数,二次函数,定义"
牛顿第一定律,一切物体在没有受到力的作用时，总保持静止状态或匀速直线运动状态,物理,力学,3,5,"牛顿定律,惯性,力学"
```

**字段说明：**
- `title` (必填): 知识点标题
- `content` (必填): 知识点内容
- `subject` (必填): 所属学科
- `chapter` (选填): 所属章节
- `difficulty` (选填): 难度 1-5
- `importance` (选填): 重要程度 1-5
- `tags` (选填): 标签，多个用逗号分隔

---

## 二、必记必背批量导入模板

### JSON 格式

```json
[
  {
    "title": "元素周期表前20号元素",
    "content": "氢氦锂铍硼，碳氮氧氟氖，钠镁铝硅磷，硫氯氩钾钙",
    "subject": "化学",
    "category": "记忆口诀",
    "priority": 1
  },
  {
    "title": "三角函数诱导公式",
    "content": "奇变偶不变，符号看象限",
    "subject": "数学",
    "category": "公式",
    "priority": 1
  }
]
```

### CSV 格式

```csv
title,content,subject,category,priority
元素周期表前20号元素,氢氦锂铍硼，碳氮氧氟氖，钠镁铝硅磷，硫氯氩钾钙,化学,记忆口诀,1
三角函数诱导公式,奇变偶不变，符号看象限,数学,公式,1
```

**字段说明：**
- `title` (必填): 标题
- `content` (必填): 内容
- `subject` (必填): 所属学科
- `category` (选填): 分类
- `priority` (选填): 优先级 1-3

---

## 三、错题批量导入模板

### JSON 格式

```json
[
  {
    "content": "计算：(-3)² = ?",
    "options": "[\"A. -9\", \"B. 9\", \"C. 6\", \"D. -6\"]",
    "answer": "B",
    "analysis": "负数的平方是正数，(-3)² = (-3) × (-3) = 9",
    "subject": "数学",
    "question_type": "single_choice",
    "knowledge_point": "有理数的运算",
    "error_type": "概念错误",
    "error_reason": "混淆了负数的平方和平方的相反数"
  },
  {
    "content": "简述光合作用的过程",
    "answer": "光合作用是指绿色植物通过叶绿体，利用光能，把二氧化碳和水转化成储存着能量的有机物，并且释放出氧气的过程",
    "analysis": "光合作用分为光反应和暗反应两个阶段",
    "subject": "生物",
    "question_type": "short_answer",
    "knowledge_point": "光合作用",
    "error_type": "记忆不清",
    "error_reason": "对光合作用的过程理解不够深入"
  }
]
```

### CSV 格式

```csv
content,options,answer,analysis,subject,question_type,knowledge_point,error_type,error_reason
"计算：(-3)² = ?","[""A. -9"", ""B. 9"", ""C. 6"", ""D. -6""]",B,负数的平方是正数，(-3)² = (-3) × (-3) = 9,数学,single_choice,有理数的运算,概念错误,混淆了负数的平方和平方的相反数
简述光合作用的过程,,光合作用是指绿色植物通过叶绿体...过程,光合作用分为光反应和暗反应两个阶段,生物,short_answer,光合作用,记忆不清,对光合作用的过程理解不够深入
```

**字段说明：**
- `content` (必填): 题目内容
- `options` (选择题必填): 选项，JSON数组格式
- `answer` (必填): 正确答案
- `analysis` (选填): 解析
- `subject` (必填): 所属学科
- `question_type` (必填): 题目类型：single_choice(单选)、multi_choice(多选)、fill_blank(填空)、short_answer(简答)、true_false(判断)
- `knowledge_point` (选填): 关联知识点
- `error_type` (选填): 错误类型
- `error_reason` (选填): 错误原因

---

## 四、母题批量导入模板

### JSON 格式

```json
[
  {
    "content": "已知二次函数 f(x) = x² - 4x + 3，求其顶点坐标",
    "options": "[\"A. (2, -1)\", \"B. (-2, 1)\", \"C. (2, 1)\", \"D. (-2, -1)\"]",
    "correct_answer": "A",
    "analysis": "配方法：f(x) = (x-2)² - 1，顶点为(2, -1)",
    "subject": "数学",
    "question_type": "single_choice",
    "difficulty": 3,
    "knowledge_points": "[\"二次函数\", \"配方法\", \"顶点坐标\"]",
    "solution_method": "配方法",
    "variants": [
      {
        "content": "已知二次函数 f(x) = x² - 6x + 8，求其顶点坐标",
        "options": "[\"A. (3, -1)\", \"B. (-3, 1)\", \"C. (3, 1)\", \"D. (-3, -1)\"]",
        "correct_answer": "A",
        "analysis": "配方法：f(x) = (x-3)² - 1，顶点为(3, -1)"
      }
    ]
  }
]
```

### CSV 格式（不含变式题）

```csv
content,options,correct_answer,analysis,subject,question_type,difficulty,knowledge_points,solution_method
"已知二次函数 f(x) = x² - 4x + 3，求其顶点坐标","[""A. (2, -1)"", ""B. (-2, 1)"", ""C. (2, 1)"", ""D. (-2, -1)""]",A,配方法：f(x) = (x-2)² - 1，顶点为(2, -1),数学,single_choice,3,"[""二次函数"", ""配方法"", ""顶点坐标""]",配方法
```

**字段说明：**
- `content` (必填): 母题内容
- `options` (选择题必填): 选项，JSON数组格式
- `correct_answer` (必填): 正确答案
- `analysis` (选填): 解析
- `subject` (必填): 所属学科
- `question_type` (必填): 题目类型
- `difficulty` (选填): 难度 1-5
- `knowledge_points` (选填): 关联知识点，JSON数组格式
- `solution_method` (选填): 解题方法
- `variants` (JSON格式选填): 变式题数组

---

## 五、学习笔记批量导入模板

### JSON 格式

```json
[
  {
    "title": "函数学习笔记",
    "content": "函数是描述变量之间对应关系的数学概念...",
    "subject": "数学",
    "tags": "[\"函数\", \"定义域\", \"值域\"]",
    "is_important": true
  },
  {
    "title": "英语语法：时态总结",
    "content": "一般现在时表示经常性、习惯性的动作或状态...",
    "subject": "英语",
    "tags": "[\"语法\", \"时态\"]",
    "is_important": false
  }
]
```

### CSV 格式

```csv
title,content,subject,tags,is_important
函数学习笔记,函数是描述变量之间对应关系的数学概念...,数学,"[""函数"", ""定义域"", ""值域"]",true
英语语法：时态总结,一般现在时表示经常性、习惯性的动作或状态...,英语,"[""语法"", ""时态"]",false
```

**字段说明：**
- `title` (必填): 笔记标题
- `content` (必填): 笔记内容
- `subject` (必填): 所属学科
- `tags` (选填): 标签，JSON数组格式
- `is_important` (选填): 是否重要，true/false

---

## 使用说明

1. 复制对应类型的模板
2. 按照字段说明填写数据
3. 在 APP 中进入对应类型列表
4. 点击右上角"批量导入"按钮
5. 粘贴数据，预览确认后导入

## 注意事项

- JSON 格式需要确保格式正确，可使用在线 JSON 验证工具检查
- CSV 格式中如果内容包含逗号，需要用双引号包裹
- 必填字段不能为空，否则该行数据会被跳过
- 导入前建议先备份数据
