// Converte os 4 planos de teste em Markdown pra .docx bem formatado.
// Usa docx@9.6.1 já instalado no package.json.
// Uso: node generate_qa_plans.js

const {
  Document, Packer, Paragraph, TextRun, HeadingLevel,
  Table, TableRow, TableCell, WidthType, BorderStyle, ShadingType,
  AlignmentType, PageBreak, TabStopType, TabStopPosition, UnderlineType,
} = require('docx');
const fs = require('fs');
const path = require('path');

const COLOR = {
  primary: '0F3460',   // azul escuro — H1
  secondary: '1A1A2E', // quase preto — H2
  accent: '22C55E',    // verde — destaque positivo
  muted: '6C757D',     // cinza — metadados
  red: 'DC2626',       // crítico
  orange: 'EA580C',    // alta
  yellow: 'CA8A04',    // média
  blue: '2563EB',      // baixa
  codeBg: 'F3F4F6',
  tableHeader: 'E0E7FF',
};

// ---------- Inline formatting (bold, italic, code) ----------
function parseInline(text, baseRunProps = {}) {
  const runs = [];
  let rest = text;
  const regex = /(\*\*([^*]+)\*\*|__([^_]+)__|\*([^*]+)\*|_([^_]+)_|`([^`]+)`)/;
  while (rest.length > 0) {
    const m = rest.match(regex);
    if (!m) {
      if (rest) runs.push(new TextRun({ ...baseRunProps, text: rest }));
      break;
    }
    if (m.index > 0) {
      runs.push(new TextRun({ ...baseRunProps, text: rest.slice(0, m.index) }));
    }
    const [full, , bold1, bold2, ital1, ital2, code] = m;
    if (bold1 || bold2) {
      runs.push(new TextRun({ ...baseRunProps, text: bold1 || bold2, bold: true }));
    } else if (ital1 || ital2) {
      runs.push(new TextRun({ ...baseRunProps, text: ital1 || ital2, italics: true }));
    } else if (code) {
      runs.push(new TextRun({ ...baseRunProps, text: code, font: 'Consolas', shading: { type: ShadingType.SOLID, color: COLOR.codeBg } }));
    }
    rest = rest.slice(m.index + full.length);
  }
  return runs.length ? runs : [new TextRun({ ...baseRunProps, text })];
}

function priorityColor(text) {
  const lc = (text || '').toLowerCase();
  if (lc.includes('crítica') || lc.includes('critica')) return COLOR.red;
  if (lc.includes('alta')) return COLOR.orange;
  if (lc.includes('média') || lc.includes('media')) return COLOR.yellow;
  if (lc.includes('baixa')) return COLOR.blue;
  return null;
}

// ---------- Paragraph builders ----------
function h1(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    spacing: { before: 400, after: 200 },
    children: parseInline(text, { bold: true, color: COLOR.primary, size: 32 }),
  });
}
function h2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    spacing: { before: 300, after: 150 },
    children: parseInline(text, { bold: true, color: COLOR.secondary, size: 26 }),
  });
}
function h3(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_3,
    spacing: { before: 200, after: 100 },
    children: parseInline(text, { bold: true, color: COLOR.secondary, size: 22 }),
  });
}
function h4(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_4,
    spacing: { before: 150, after: 80 },
    children: parseInline(text, { bold: true, color: COLOR.secondary, size: 20 }),
  });
}
function h5(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_5,
    spacing: { before: 120, after: 60 },
    children: parseInline(text, { bold: true, color: COLOR.muted, size: 20 }),
  });
}
function para(text) {
  return new Paragraph({
    spacing: { after: 100 },
    children: parseInline(text, { size: 22 }),
  });
}
function blockquote(text) {
  return new Paragraph({
    spacing: { after: 120 },
    indent: { left: 400 },
    shading: { type: ShadingType.SOLID, color: 'F9FAFB' },
    children: parseInline(text, { italics: true, size: 22, color: COLOR.muted }),
  });
}
function bullet(text, level = 0) {
  return new Paragraph({
    bullet: { level },
    spacing: { after: 60 },
    children: parseInline(text, { size: 22 }),
  });
}
function numbered(text, level = 0) {
  return new Paragraph({
    numbering: { reference: 'default-numbered', level },
    spacing: { after: 60 },
    children: parseInline(text, { size: 22 }),
  });
}
function codeBlock(lines) {
  return lines.map(line => new Paragraph({
    spacing: { after: 0 },
    shading: { type: ShadingType.SOLID, color: COLOR.codeBg },
    children: [new TextRun({ text: line || ' ', font: 'Consolas', size: 18 })],
  }));
}

// ---------- Table builder ----------
function buildTable(headers, rows) {
  const BORDERS = {
    top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
    bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
    left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
    right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
    insideHorizontal: { style: BorderStyle.SINGLE, size: 2, color: 'E2E8F0' },
    insideVertical: { style: BorderStyle.SINGLE, size: 2, color: 'E2E8F0' },
  };

  const headerRow = new TableRow({
    tableHeader: true,
    children: headers.map(h => new TableCell({
      shading: { type: ShadingType.SOLID, color: COLOR.tableHeader },
      children: [new Paragraph({ children: parseInline(h, { bold: true, size: 20 }) })],
    })),
  });

  const dataRows = rows.map(row => new TableRow({
    children: row.map((cell, idx) => {
      const pColor = (idx < headers.length && /priorid/i.test(headers[idx] || '')) ? priorityColor(cell) : null;
      return new TableCell({
        children: [new Paragraph({ children: parseInline(cell, { size: 20, color: pColor, bold: !!pColor }) })],
      });
    }),
  }));

  return new Table({
    rows: [headerRow, ...dataRows],
    width: { size: 100, type: WidthType.PERCENTAGE },
    borders: BORDERS,
  });
}

// ---------- Markdown parser (stateful) ----------
function parseMarkdown(md) {
  const lines = md.split(/\r?\n/);
  const children = [];
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];

    // Code block
    if (line.trim().startsWith('```')) {
      i++;
      const code = [];
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        code.push(lines[i]);
        i++;
      }
      i++; // skip closing ```
      children.push(...codeBlock(code));
      continue;
    }

    // Table
    if (line.startsWith('|') && lines[i + 1] && /^\|[\s\-:|]+\|$/.test(lines[i + 1].trim())) {
      const headers = line.split('|').slice(1, -1).map(s => s.trim());
      i += 2; // skip header + separator
      const rows = [];
      while (i < lines.length && lines[i].startsWith('|')) {
        const row = lines[i].split('|').slice(1, -1).map(s => s.trim());
        rows.push(row);
        i++;
      }
      children.push(buildTable(headers, rows));
      children.push(para(''));
      continue;
    }

    // Horizontal rule
    if (/^\s*---+\s*$/.test(line)) {
      children.push(new Paragraph({
        spacing: { before: 100, after: 100 },
        border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: 'CBD5E1' } },
        children: [new TextRun({ text: '' })],
      }));
      i++;
      continue;
    }

    // Headings
    const h = line.match(/^(#{1,5})\s+(.+)$/);
    if (h) {
      const lvl = h[1].length;
      const text = h[2];
      if (lvl === 1) children.push(h1(text));
      else if (lvl === 2) children.push(h2(text));
      else if (lvl === 3) children.push(h3(text));
      else if (lvl === 4) children.push(h4(text));
      else children.push(h5(text));
      i++;
      continue;
    }

    // Blockquote
    if (line.startsWith('> ')) {
      // Collect consecutive quote lines
      let quoteText = line.slice(2);
      i++;
      while (i < lines.length && lines[i].startsWith('> ')) {
        quoteText += ' ' + lines[i].slice(2);
        i++;
      }
      children.push(blockquote(quoteText));
      continue;
    }

    // Bullet list
    if (/^\s*- /.test(line)) {
      const indent = (line.match(/^ */) || [''])[0].length;
      const level = Math.floor(indent / 2);
      const text = line.replace(/^\s*- /, '');
      children.push(bullet(text, level));
      i++;
      continue;
    }

    // Numbered list
    if (/^\s*\d+\.\s/.test(line)) {
      const indent = (line.match(/^ */) || [''])[0].length;
      const level = Math.floor(indent / 2);
      const text = line.replace(/^\s*\d+\.\s/, '');
      children.push(numbered(text, level));
      i++;
      continue;
    }

    // Empty line → small spacing paragraph
    if (line.trim() === '') {
      i++;
      continue;
    }

    // Plain paragraph (may span multiple non-empty lines)
    let parText = line;
    i++;
    while (
      i < lines.length &&
      lines[i].trim() !== '' &&
      !/^#{1,5}\s/.test(lines[i]) &&
      !lines[i].startsWith('|') &&
      !lines[i].startsWith('> ') &&
      !/^\s*-\s/.test(lines[i]) &&
      !/^\s*\d+\.\s/.test(lines[i]) &&
      !/^\s*---+\s*$/.test(lines[i]) &&
      !lines[i].trim().startsWith('```')
    ) {
      parText += ' ' + lines[i].trim();
      i++;
    }
    children.push(para(parText));
  }

  return children;
}

// ---------- Main ----------
const docs = [
  { md: 'PLANO_TESTES_FRONTDESK.md', out: 'PLANO_TESTES_FRONTDESK.docx', title: 'Plano de Testes — KLaOS Frontdesk' },
  { md: 'PLANO_TESTES_KLAOS_CRM.md', out: 'PLANO_TESTES_KLAOS_CRM.docx', title: 'Plano de Testes — KLaOS CRM' },
  { md: 'PLANO_TESTES_AI_AGENTS.md', out: 'PLANO_TESTES_AI_AGENTS.docx', title: 'Plano de Testes — KLaOS AI Agents' },
  { md: 'PLANO_TESTES_INTEGRACAO.md', out: 'PLANO_TESTES_INTEGRACAO.docx', title: 'Plano de Testes — Integração KLaOS' },
];

async function run() {
  for (const { md, out, title } of docs) {
    const mdPath = path.join(__dirname, md);
    if (!fs.existsSync(mdPath)) {
      console.error(`MISSING: ${md}`);
      continue;
    }
    const content = fs.readFileSync(mdPath, 'utf8');
    const children = parseMarkdown(content);

    const doc = new Document({
      creator: 'KLaOS QA',
      title,
      description: `Plano de Testes — ${title}`,
      numbering: {
        config: [
          {
            reference: 'default-numbered',
            levels: [
              { level: 0, format: 'decimal', text: '%1.', alignment: AlignmentType.START },
              { level: 1, format: 'decimal', text: '%2.', alignment: AlignmentType.START },
            ],
          },
        ],
      },
      styles: {
        default: {
          document: { run: { font: 'Calibri', size: 22 } },
        },
      },
      sections: [{
        properties: { page: { margin: { top: 1000, bottom: 1000, left: 1200, right: 1200 } } },
        children,
      }],
    });

    const buffer = await Packer.toBuffer(doc);
    const outPath = path.join(__dirname, out);
    fs.writeFileSync(outPath, buffer);
    console.log(`✓ ${out}  (${(buffer.length / 1024).toFixed(1)} KB)`);
  }
  console.log('\nPronto.');
}

run().catch(e => { console.error(e); process.exit(1); });
