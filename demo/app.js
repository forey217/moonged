import { run_json } from '/_build/host/engine.mjs';
const $ = id => document.getElementById(id);
let report, currentText = '', generation = 0;
const relations = { parent: '记录中的父母', child: '记录中的子女', partner: '家庭伴侣' };
function call(command, text, extra = {}) {
  const response = JSON.parse(run_json(JSON.stringify({ command, text, ...extra })));
  if (!response.ok) throw new Error(`${response.line ? `第 ${response.line} 行 · ` : ''}${response.error}`);
  return response.result;
}
function element(tag, text, className) {
  const e = document.createElement(tag);
  if (text !== undefined) e.textContent = text;
  if (className) e.className = className;
  return e;
}
function invalidate() {
  generation++;
  report = undefined;
  for (const id of ['query', 'download-ged', 'download-csv', 'download-report']) $(id).disabled = true;
  $('source-status').textContent = '内容已变化，请重新检查。';
  $('validation-status').textContent = '需重新检查';
  $('path').textContent = '';
  for (const id of ['people-count','family-count','audit-count']) $(id).textContent = '—';
  $('families').replaceChildren(element('div', '请重新检查当前文本。', 'empty'));
  $('diagnostics').replaceChildren(element('div', '等待检查当前文本。', 'empty'));
  $('from').replaceChildren(); $('to').replaceChildren();
}
function diagnosticMessage(d) {
  const messages = {
    'dangling-pointer':'引用的标识没有对应记录', 'duplicate-id':'同一个标识被定义了多次',
    'pointer-type':'引用目标的记录类型不正确', 'pointer-payload':'这个字段需要记录引用或空引用',
    'unsupported-version':'只支持 GEDCOM 7.0，请先确认文件版本', 'missing-header':'文件第一条记录应为 HEAD',
    'missing-trailer':'文件最后一条记录应为 TRLR', 'header-version':'文件头必须声明 GEDCOM 版本',
    'empty-structure':'结构需要有内容或子结构', 'trailer-order':'TRLR 必须在最后，且不能有子结构',
    'undeclared-extension':'扩展字段已保留，但未在文件头声明来源', 'invalid-date':'日期格式或日历日期不正确',
    'unsupported-calendar':'该日历原文已保留，暂不进行日期计算', 'birth-after-death':'出生日期范围晚于死亡日期范围，请核查记录',
    'ancestry-cycle':'记录中的父母关系形成环路，请核查非生物关系',
    'missing-reciprocal-famc':'家庭记录有子女链接，但人物记录缺少对应的 FAMC',
    'missing-reciprocal-fams':'家庭记录有伴侣链接，但人物记录缺少对应的 FAMS',
    'missing-reciprocal-chil':'人物有 FAMC 链接，但家庭缺少对应的 CHIL',
    'missing-reciprocal-partner':'人物有 FAMS 链接，但家庭缺少对应的伴侣链接',
    'family-cardinality':'家庭的 HUSB 或 WIFE 字段出现多次', 'duplicate-family-link':'家庭中重复引用了同一条记录',
    'structure-context':'这个标准字段放在了不允许的位置', 'structure-cardinality':'标准单例字段重复出现',
    'required-structure':'缺少标准要求的子结构', 'payload-type':'字段内容不符合该位置的数据类型或取值范围',
    'schema-pointer-type':'引用的目标不符合标准类型', 'required-reciprocal-link':'家庭成员缺少必须的反向引用',
    'source-reference-cycle':'来源、共享备注或媒体记录之间存在禁止的循环引用',
    'translation-format':'翻译缺少语言或格式说明', 'translation-distinct':'翻译的有效语言和格式与原文相同',
    'translation-duplicate':'同级翻译的有效语言和格式重复', 'refn-reuse':'不同结构重复使用了同一个 REFN',
    'extension-unassessed':'扩展内容已保存，外部语义尚未评估',
    'date-arithmetic-limit':'日期格式合法，但年份超过运算资源范围',
    'date-arithmetic-unassessed':'日期已保留，该历法或年份没有擅自换算',
    'html-entity':'HTML 备注包含需转换为 Unicode 的非核心命名实体', 'note-mime-kind':'备注应使用文本媒体类型',
  };
  const ids = d.message.match(/@[^@]+@/g) ?? [];
  return messages[d.code] ? `${messages[d.code]}${ids.length ? '：'+ids.join('、') : ''}。` : d.message;
}
function analyze() {
  invalidate();
  try {
    currentText = $('source').value;
    report = call('inspect', currentText);
    $('people-count').textContent = report.people.length;
    $('family-count').textContent = report.families.length;
    const errors = report.diagnostics.filter(d => d.severity === 'error');
    $('audit-count').textContent = errors.length ? `${errors.length} 项错误` : '已检查';
    $('validation-status').textContent = `${report.diagnostics.length} 项诊断`;
    $('source-status').textContent = `已读取 ${report.node_count} 个结构。`;
    const byId = new Map(report.people.filter(p => p.id).map(p => [p.id, p.name]));
    const name = id => byId.get(id) ?? (id ? `@${id}@` : '未记录');
    $('families').replaceChildren();
    for (const family of report.families.slice(0, 20)) {
      const card = element('div', undefined, 'family-card');
      card.append(element('div', family.id ? `FAMILY / ${family.id}` : 'FAMILY / 无标识', 'family-id'));
      const parents = element('div', undefined, 'partners');
      parents.append(document.createTextNode(name(family.husband)), element('span', '＋'), document.createTextNode(name(family.wife)));
      card.append(parents, element('div', family.children.length ? `子女记录：${family.children.map(name).join('、')}` : '无子女记录', 'children'));
      $('families').append(card);
    }
    if (!report.families.length) $('families').append(element('div', '文件中没有 FAM 家庭记录。', 'empty'));
    if (report.families.length > 20) $('families').append(element('p', '页面展示前 20 个家庭，全部记录可通过工具库或 CLI 查询。', 'boundary'));
    for (const id of ['from', 'to']) {
      $(id).replaceChildren();
      for (const p of report.people.filter(p => p.id).slice(0, 500)) {
        const option = element('option', `${p.name} · ${p.id}`); option.value = p.id; $(id).append(option);
      }
    }
    if ($('to').options.length > 1) $('to').selectedIndex = $('to').options.length - 1;
    $('diagnostics').replaceChildren();
    for (const d of report.diagnostics.slice(0, 100)) {
      const box = element('div', undefined, `diagnostic ${d.severity}`);
      box.append(element('strong', `第 ${d.line} 行 · ${d.code}`), document.createTextNode(diagnosticMessage(d)));
      $('diagnostics').append(box);
    }
    if (!report.diagnostics.length) $('diagnostics').append(element('div', '已实施的检查规则未发现问题。可查看关系或导出文件。', 'clean'));
    $('download-report').disabled = false;
    $('download-ged').disabled = !report.valid;
    $('download-csv').disabled = !report.valid;
    $('query').disabled = !report.valid || !$('from').options.length;
  } catch (error) { $('source-status').textContent = error.message; $('validation-status').textContent = '解析失败'; }
}
async function sample(file) {
  invalidate();
  const ticket = generation;
  const text = await (await fetch(`/examples/${file}`)).text();
  if (ticket !== generation) return;
  $('source').value = text;
  analyze();
}
function download(filename, content, type) {
  const url = URL.createObjectURL(new Blob([content], { type }));
  const a = element('a'); a.href = url; a.download = filename; a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
$('source').addEventListener('input', invalidate);
$('sample').addEventListener('click', () => sample('family.ged'));
$('broken').addEventListener('click', () => sample('broken.ged'));
$('analyze').addEventListener('click', analyze);
$('file').addEventListener('change', async event => {
  invalidate();
  const file = event.target.files[0]; if (!file) return;
  const ticket = generation;
  try {
    if (file.size > 8 * 1024 * 1024) throw new Error('网页限 8 MiB 文件，大文件请使用 CLI。');
    const text = new TextDecoder('utf-8', { fatal: true }).decode(await file.arrayBuffer());
    if (ticket !== generation) return;
    $('source').value = text; analyze();
  } catch (error) { if (ticket === generation) $('source-status').textContent = error.message; }
});
$('query').addEventListener('click', () => {
  try {
    const path = call('path', currentText, { from: $('from').value, to: $('to').value });
    const names = new Map(report.people.map(p => [p.id, p.name]));
    $('path').textContent = path === null ? '未找到相连的家庭关系路径。' : path.length === 0 ? '起点和终点为同一条人物记录。' : path.map(e => `${names.get(e.from)} → ${names.get(e.to)}：${relations[e.relation]}${e.pedigree ? `（${e.pedigree}）` : ''}`).join('\n');
  } catch (error) { $('path').textContent = error.message; }
});
$('download-ged').addEventListener('click', () => download('moonged-export.ged', call('normalize', currentText), 'text/plain;charset=utf-8'));
$('download-csv').addEventListener('click', () => download('moonged-people.csv', call('csv', currentText), 'text/csv;charset=utf-8'));
$('download-report').addEventListener('click', () => download('moonged-audit.json', JSON.stringify(report, null, 2), 'application/json'));
sample('family.ged').catch(error => { $('source-status').textContent = error.message; });
