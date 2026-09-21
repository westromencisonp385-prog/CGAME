"""Build the Chinese planning report PDF with ReportLab.

This is intentionally a small Markdown subset renderer for the checked-in
planning report. It keeps the source Markdown as the canonical editable file.
"""
from __future__ import annotations

import html
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    HRFlowable,
    KeepTogether,
    PageBreak,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "wanderburg-to-excavator-plan.md"
OUTPUT = ROOT / "docs" / "wanderburg-to-excavator-plan.pdf"

pdfmetrics.registerFont(UnicodeCIDFont("STSong-Light"))
FONT = "STSong-Light"


def inline(value: str) -> str:
    value = html.escape(value, quote=False)
    value = re.sub(
        r"\[([^\]]+)\]\(([^)]+)\)",
        lambda m: f'<link href="{html.escape(m.group(2), quote=True)}" color="#1e6fa8">{m.group(1)}</link>',
        value,
    )
    value = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", value)
    value = re.sub(r"`([^`]+)`", r'<font name="Courier">\1</font>', value)
    return value


def make_styles():
    styles = getSampleStyleSheet()
    return {
        "body": ParagraphStyle(
            "BodyCN", parent=styles["BodyText"], fontName=FONT, fontSize=9.3,
            leading=15, textColor=colors.HexColor("#253746"), spaceAfter=5,
            alignment=TA_LEFT,
        ),
        "h1": ParagraphStyle(
            "H1CN", parent=styles["Heading1"], fontName=FONT, fontSize=17,
            leading=23, textColor=colors.HexColor("#134b6f"), spaceBefore=12,
            spaceAfter=8, keepWithNext=True,
        ),
        "h2": ParagraphStyle(
            "H2CN", parent=styles["Heading2"], fontName=FONT, fontSize=13,
            leading=18, textColor=colors.HexColor("#1e7a50"), spaceBefore=10,
            spaceAfter=5, keepWithNext=True,
        ),
        "h3": ParagraphStyle(
            "H3CN", parent=styles["Heading3"], fontName=FONT, fontSize=11,
            leading=15, textColor=colors.HexColor("#236f9f"), spaceBefore=7,
            spaceAfter=4, keepWithNext=True,
        ),
        "bullet": ParagraphStyle(
            "BulletCN", parent=styles["BodyText"], fontName=FONT, fontSize=9.1,
            leading=14, leftIndent=13, firstLineIndent=-8, spaceAfter=3,
        ),
        "quote": ParagraphStyle(
            "QuoteCN", parent=styles["BodyText"], fontName=FONT, fontSize=9,
            leading=14, leftIndent=10, borderColor=colors.HexColor("#2e86c1"),
            borderWidth=2, borderPadding=5, backColor=colors.HexColor("#f2f6f8"),
            textColor=colors.HexColor("#536875"), spaceAfter=6,
        ),
        "code": ParagraphStyle(
            "CodeCN", parent=styles["Code"], fontName="Courier", fontSize=7.4,
            leading=10, backColor=colors.HexColor("#f5f1eb"), leftIndent=8,
            rightIndent=8, borderPadding=5, spaceAfter=6,
        ),
        "cover_title": ParagraphStyle(
            "CoverTitleCN", parent=styles["Title"], fontName=FONT, fontSize=25,
            leading=34, textColor=colors.HexColor("#134b6f"), alignment=TA_CENTER,
            spaceAfter=10,
        ),
        "cover_sub": ParagraphStyle(
            "CoverSubCN", parent=styles["Normal"], fontName=FONT, fontSize=12,
            leading=18, textColor=colors.HexColor("#6f7f88"), alignment=TA_CENTER,
            spaceAfter=10,
        ),
        "table": ParagraphStyle(
            "TableCN", parent=styles["BodyText"], fontName=FONT, fontSize=7.2,
            leading=10, textColor=colors.HexColor("#253746"),
        ),
        "table_header": ParagraphStyle(
            "TableHeaderCN", parent=styles["BodyText"], fontName=FONT, fontSize=7.4,
            leading=10, textColor=colors.white,
        ),
    }


def is_table_row(line: str) -> bool:
    return line.strip().startswith("|") and line.strip().endswith("|")


def table_from(rows: list[str], styles):
    values = []
    for row in rows:
        cells = [c.strip() for c in row.strip().strip("|").split("|")]
        if all(re.fullmatch(r":?-{3,}:?", c) for c in cells):
            continue
        values.append(cells)
    if not values:
        return None
    width = max(len(row) for row in values)
    values = [row + [""] * (width - len(row)) for row in values]
    wrapped = []
    for i, row in enumerate(values):
        style = styles["table_header"] if i == 0 else styles["table"]
        wrapped.append([Paragraph(inline(cell), style) for cell in row])
    col_width = 170 * mm / width
    table = Table(wrapped, colWidths=[col_width] * width, repeatRows=1, hAlign="LEFT")
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#174f70")),
        ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#b8c4c9")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f5f8f9")]),
    ]))
    return table


def parse_markdown(text: str, styles):
    lines = text.splitlines()
    story = []
    para: list[str] = []
    table_rows: list[str] = []
    in_code = False
    code_lines: list[str] = []

    def flush_para():
        nonlocal para
        if para:
            joined = " ".join(x.strip() for x in para)
            story.append(Paragraph(inline(joined), styles["body"]))
            para = []

    def flush_table():
        nonlocal table_rows
        if table_rows:
            flush_para()
            table = table_from(table_rows, styles)
            if table:
                story.append(table)
                story.append(Spacer(1, 4))
            table_rows = []

    for raw in lines:
        line = raw.rstrip()
        if line.startswith("```"):
            flush_para(); flush_table()
            if in_code:
                story.append(Paragraph(html.escape("\n".join(code_lines)), styles["code"]))
                code_lines = []
                in_code = False
            else:
                in_code = True
            continue
        if in_code:
            code_lines.append(line)
            continue
        if is_table_row(line):
            flush_para()
            table_rows.append(line)
            continue
        if table_rows:
            flush_table()
        if not line.strip():
            flush_para()
            continue
        heading = re.match(r"^(#{1,3})\s+(.+)$", line)
        if heading:
            flush_para()
            level = len(heading.group(1))
            story.append(Paragraph(inline(heading.group(2)), styles[f"h{level}"]))
            continue
        if line.startswith(">"):
            flush_para()
            story.append(Paragraph(inline(line[1:].strip()), styles["quote"]))
            continue
        bullet = re.match(r"^\s*([-*]|\d+\.)\s+(.+)$", line)
        if bullet:
            flush_para()
            marker = bullet.group(1)
            story.append(Paragraph(f"{marker} {inline(bullet.group(2))}", styles["bullet"]))
            continue
        para.append(line)
    if in_code:
        story.append(Paragraph(html.escape("\n".join(code_lines)), styles["code"]))
    flush_para(); flush_table()
    return story


class PlanDocTemplate(BaseDocTemplate):
    def __init__(self, filename, **kwargs):
        super().__init__(filename, **kwargs)
        frame = Frame(self.leftMargin, self.bottomMargin, self.width, self.height, id="normal")
        self.addPageTemplates([__import__("reportlab.platypus").platypus.PageTemplate(id="main", frames=[frame], onPage=self.footer)])

    def footer(self, canvas, doc):
        canvas.saveState()
        canvas.setStrokeColor(colors.HexColor("#174f70"))
        canvas.setLineWidth(0.4)
        canvas.line(doc.leftMargin, 14 * mm, A4[0] - doc.rightMargin, 14 * mm)
        canvas.setFont(FONT, 7.5)
        canvas.setFillColor(colors.HexColor("#839199"))
        canvas.drawString(doc.leftMargin, 9 * mm, "挖掘机拯救世界 · 立项与技术规划")
        canvas.drawRightString(A4[0] - doc.rightMargin, 9 * mm, f"第 {doc.page} 页")
        canvas.restoreState()


def main():
    styles = make_styles()
    source = SOURCE.read_text(encoding="utf-8")
    doc = PlanDocTemplate(
        str(OUTPUT), pagesize=A4, leftMargin=20 * mm, rightMargin=20 * mm,
        topMargin=17 * mm, bottomMargin=20 * mm, title="挖掘机拯救世界：从 Wanderburg 参考到 Steam 独立游戏计划",
        author="Codex",
    )
    story = [Spacer(1, 50 * mm), Paragraph("《挖掘机拯救世界》", styles["cover_title"]),
             Paragraph("从 Wanderburg 参考到 Steam 独立游戏计划", styles["cover_sub"]),
             HRFlowable(width="55%", thickness=1.2, color=colors.HexColor("#174f70"), hAlign="CENTER"),
             Spacer(1, 8 * mm), Paragraph("Godot 4.6.3 · Windows Steam 单机 · 个人主导 + AI 协作 + 必要外包", styles["cover_sub"]),
             Paragraph("研究与立项基线 · 2026-09-20", styles["cover_sub"]), PageBreak()]
    story.extend(parse_markdown(source, styles))
    doc.build(story)
    print(f"wrote {OUTPUT} ({OUTPUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
