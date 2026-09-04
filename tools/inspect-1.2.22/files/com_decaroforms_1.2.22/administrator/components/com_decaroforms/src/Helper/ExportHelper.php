<?php

namespace DeCaro\Component\Forms\Administrator\Helper;

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\Database\DatabaseInterface;

final class ExportHelper
{
    public static function loadRows(int $formId, string $query = '', string $status = 'all', array $onlyIds = []): array
    {
        /** @var DatabaseInterface $db */
        $db = Factory::getContainer()->get(DatabaseInterface::class);
        $q = $db->createQuery()
            ->select('*')
            ->from($db->quoteName('#__decaroforms_submissions'))
            ->where($db->quoteName('form_id') . ' = :fid')
            ->bind(':fid', $formId)
            ->order($db->quoteName('created_at') . ' DESC');

        if ($query !== '') {
            $like = '%' . str_replace(['%', '_'], ['\\%', '\\_'], $query) . '%';
            $q->where('(' . $db->quoteName('reference') . ' LIKE :q OR ' . $db->quoteName('email') . ' LIKE :q)')
              ->bind(':q', $like);
        }
        if ($status !== '' && $status !== 'all' && preg_match('/^[a-z0-9_-]{1,30}$/', $status)) {
            $q->where($db->quoteName('status') . ' = :status')->bind(':status', $status);
        }
        if ($onlyIds) {
            $onlyIds = array_values(array_unique(array_filter(array_map('intval', $onlyIds), static fn(int $id): bool => $id > 0)));
            if ($onlyIds) {
                $q->whereIn($db->quoteName('id'), $onlyIds);
            }
        }
        $db->setQuery($q);
        $rows = $db->loadAssocList() ?: [];
        if (!$rows) { return []; }

        $ids = array_map(static fn(array $row): int => (int) $row['id'], $rows);
        $attachments = [];
        $fq = $db->createQuery()
            ->select([$db->quoteName('submission_id'), $db->quoteName('file_name')])
            ->from($db->quoteName('#__decaroforms_files'))
            ->whereIn($db->quoteName('submission_id'), $ids)
            ->order($db->quoteName('id') . ' ASC');
        $db->setQuery($fq);
        foreach ($db->loadAssocList() ?: [] as $file) {
            $attachments[(int) $file['submission_id']][] = (string) $file['file_name'];
        }

        foreach ($rows as &$row) {
            $row['_payload'] = json_decode((string) ($row['payload_json'] ?? ''), true) ?: [];
            $row['_attachments'] = $attachments[(int) $row['id']] ?? [];
        }
        unset($row);
        return $rows;
    }

    public static function matrix(array $rows, array $statuses = []): array
    {
        $payloadHeaders = [];
        $normalizedPayloads = [];
        foreach ($rows as $idx => $row) {
            $normalizedPayloads[$idx] = [];
            foreach (($row['_payload'] ?? []) as $key => $value) {
                $label = FormHelper::localizedPayloadLabel((string) $key);
                $normalizedPayloads[$idx][$label] = FormHelper::localizedPayloadValue((string) $key, $value);
                if (!in_array($label, $payloadHeaders, true)) { $payloadHeaders[] = $label; }
            }
        }

        $headers = array_merge([
            Text::_('COM_DECAROFORMS_REFERENCE'),
            Text::_('COM_DECAROFORMS_EMAIL'),
            Text::_('COM_DECAROFORMS_STATUS'),
            Text::_('COM_DECAROFORMS_DATE'),
        ], $payloadHeaders, [
            Text::_('COM_DECAROFORMS_ATTACHMENTS'),
            Text::_('COM_DECAROFORMS_INTERNAL_NOTE'),
        ]);

        $data = [];
        foreach ($rows as $idx => $row) {
            $line = [
                (string) ($row['reference'] ?? ''),
                (string) ($row['email'] ?? ''),
                FormHelper::statusLabel((string) ($row['status'] ?? 'new'), $statuses),
                (string) ($row['created_at'] ?? ''),
            ];
            foreach ($payloadHeaders as $header) {
                $line[] = (string) ($normalizedPayloads[$idx][$header] ?? '');
            }
            $line[] = implode(', ', $row['_attachments'] ?? []);
            $line[] = (string) ($row['internal_note'] ?? '');
            $data[] = $line;
        }
        return [$headers, $data];
    }

    public static function csv(array $headers, array $rows): string
    {
        $fp = fopen('php://temp', 'w+');
        fwrite($fp, "\xEF\xBB\xBF");
        fputcsv($fp, $headers, ';');
        foreach ($rows as $row) { fputcsv($fp, $row, ';'); }
        rewind($fp);
        $content = stream_get_contents($fp) ?: '';
        fclose($fp);
        return $content;
    }

    public static function xlsx(array $headers, array $rows): string
    {
        $sheetRows = array_merge([$headers], $rows);
        $sheet = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            . '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            . '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'
            . '<sheetData>';
        foreach ($sheetRows as $ri => $row) {
            $r = $ri + 1; $sheet .= '<row r="' . $r . '">';
            foreach (array_values($row) as $ci => $value) {
                $cell = self::columnName($ci + 1) . $r;
                $style = $ri === 0 ? ' s="1"' : '';
                $sheet .= '<c r="' . $cell . '" t="inlineStr"' . $style . '><is><t xml:space="preserve">' . self::xml((string) $value) . '</t></is></c>';
            }
            $sheet .= '</row>';
        }
        $lastCol = self::columnName(max(1, count($headers)));
        $sheet .= '</sheetData><autoFilter ref="A1:' . $lastCol . '1"/></worksheet>';

        return self::zip([
            '[Content_Types].xml' => '<?xml version="1.0" encoding="UTF-8"?>'
                . '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
                . '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
                . '<Default Extension="xml" ContentType="application/xml"/>'
                . '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
                . '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
                . '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
                . '</Types>',
            '_rels/.rels' => '<?xml version="1.0" encoding="UTF-8"?>'
                . '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                . '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
                . '</Relationships>',
            'xl/workbook.xml' => '<?xml version="1.0" encoding="UTF-8"?>'
                . '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
                . '<sheets><sheet name="Submissions" sheetId="1" r:id="rId1"/></sheets></workbook>',
            'xl/_rels/workbook.xml.rels' => '<?xml version="1.0" encoding="UTF-8"?>'
                . '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                . '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
                . '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
                . '</Relationships>',
            'xl/styles.xml' => '<?xml version="1.0" encoding="UTF-8"?>'
                . '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
                . '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
                . '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>'
                . '<borders count="1"><border/></borders>'
                . '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
                . '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>'
                . '</styleSheet>',
            'xl/worksheets/sheet1.xml' => $sheet,
        ]);
    }

    public static function pdf(string $title, array $rows, array $statuses = []): string
    {
        $lines = [];
        $lines[] = $title;
        $lines[] = Text::_('COM_DECAROFORMS_EXPORT_GENERATED') . ': ' . Factory::getDate()->format('Y-m-d H:i:s');
        $lines[] = '';
        foreach ($rows as $row) {
            $lines[] = (string) ($row['reference'] ?? '');
            $lines[] = Text::_('COM_DECAROFORMS_EMAIL') . ': ' . (string) ($row['email'] ?? '');
            $lines[] = Text::_('COM_DECAROFORMS_STATUS') . ': ' . FormHelper::statusLabel((string) ($row['status'] ?? 'new'), $statuses);
            $lines[] = Text::_('COM_DECAROFORMS_DATE') . ': ' . (string) ($row['created_at'] ?? '');
            foreach (($row['_payload'] ?? []) as $key => $value) {
                $lines[] = FormHelper::localizedPayloadLabel((string) $key) . ': ' . FormHelper::localizedPayloadValue((string) $key, $value);
            }
            if (!empty($row['_attachments'])) { $lines[] = Text::_('COM_DECAROFORMS_ATTACHMENTS') . ': ' . implode(', ', $row['_attachments']); }
            if (!empty($row['internal_note'])) { $lines[] = Text::_('COM_DECAROFORMS_INTERNAL_NOTE') . ': ' . (string) $row['internal_note']; }
            $lines[] = str_repeat('-', 82);
        }

        $wrapped = [];
        foreach ($lines as $line) {
            $line = preg_replace('/\s+/u', ' ', trim((string) $line)) ?? '';
            if ($line === '') { $wrapped[] = ''; continue; }
            foreach (self::wrap($line, 88) as $part) { $wrapped[] = $part; }
        }
        $perPage = 54;
        $pages = array_chunk($wrapped, $perPage);
        if (!$pages) { $pages = [[]]; }

        $objects = [];
        $objects[1] = '<< /Type /Catalog /Pages 2 0 R >>';
        $pageIds = [];
        $nextId = 4;
        foreach ($pages as $pageIndex => $pageLines) {
            $pageId = $nextId++; $contentId = $nextId++; $pageIds[] = $pageId;
            $stream = "BT\n/F1 10 Tf\n40 800 Td\n14 TL\n";
            foreach ($pageLines as $i => $line) {
                if ($i > 0) { $stream .= "T*\n"; }
                $stream .= '(' . self::pdfText($line) . ") Tj\n";
            }
            $stream .= "ET";
            $objects[$contentId] = '<< /Length ' . strlen($stream) . " >>\nstream\n" . $stream . "\nendstream";
            $objects[$pageId] = '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R >> >> /Contents ' . $contentId . ' 0 R >>';
        }
        $objects[2] = '<< /Type /Pages /Kids [' . implode(' ', array_map(static fn($id) => $id . ' 0 R', $pageIds)) . '] /Count ' . count($pageIds) . ' >>';
        $objects[3] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>';
        ksort($objects);
        $pdf = "%PDF-1.4\n";
        $offsets = [0];
        $maxId = max(array_keys($objects));
        for ($i = 1; $i <= $maxId; $i++) {
            $offsets[$i] = strlen($pdf);
            $pdf .= $i . " 0 obj\n" . ($objects[$i] ?? '<<>>') . "\nendobj\n";
        }
        $xref = strlen($pdf);
        $pdf .= "xref\n0 " . ($maxId + 1) . "\n0000000000 65535 f \n";
        for ($i = 1; $i <= $maxId; $i++) { $pdf .= sprintf("%010d 00000 n \n", $offsets[$i]); }
        $pdf .= "trailer\n<< /Size " . ($maxId + 1) . " /Root 1 0 R >>\nstartxref\n" . $xref . "\n%%EOF";
        return $pdf;
    }

    private static function xml(string $value): string
    {
        return htmlspecialchars(self::cleanControlChars($value), ENT_XML1 | ENT_QUOTES, 'UTF-8');
    }

    private static function cleanControlChars(string $value): string
    {
        return preg_replace('/[^\P{C}\t\r\n]/u', '', $value) ?? $value;
    }

    private static function columnName(int $number): string
    {
        $name = '';
        while ($number > 0) { $number--; $name = chr(65 + ($number % 26)) . $name; $number = intdiv($number, 26); }
        return $name;
    }

    private static function zip(array $files): string
    {
        $local = '';
        $central = '';
        $offset = 0;
        $now = getdate();
        $dosTime = (($now['hours'] & 0x1f) << 11) | (($now['minutes'] & 0x3f) << 5) | ((int) ($now['seconds'] / 2) & 0x1f);
        $dosDate = (((max(1980, $now['year']) - 1980) & 0x7f) << 9) | (($now['mon'] & 0x0f) << 5) | ($now['mday'] & 0x1f);

        foreach ($files as $name => $data) {
            $name = str_replace('\\', '/', (string) $name);
            $data = (string) $data;
            $crc = crc32($data);
            $compressed = function_exists('gzdeflate') ? gzdeflate($data, 6) : false;
            if ($compressed === false) { $compressed = $data; $method = 0; } else { $method = 8; }
            $csize = strlen($compressed);
            $usize = strlen($data);
            $nlen = strlen($name);

            $header = pack('VvvvvvVVVvv', 0x04034b50, 20, 0, $method, $dosTime, $dosDate, $crc, $csize, $usize, $nlen, 0) . $name;
            $local .= $header . $compressed;

            $central .= pack('VvvvvvvVVVvvvvvVV', 0x02014b50, 20, 20, 0, $method, $dosTime, $dosDate, $crc, $csize, $usize, $nlen, 0, 0, 0, 0, 0, $offset) . $name;
            $offset += strlen($header) + $csize;
        }
        $count = count($files);
        return $local . $central . pack('VvvvvVVv', 0x06054b50, 0, 0, $count, $count, strlen($central), strlen($local), 0);
    }

    private static function wrap(string $text, int $width): array
    {
        $parts = preg_split('/\s+/u', $text) ?: [$text];
        $lines = []; $line = '';
        foreach ($parts as $word) {
            if ($line === '') { $line = $word; continue; }
            if ((function_exists('mb_strlen') ? mb_strlen($line . ' ' . $word, 'UTF-8') : strlen($line . ' ' . $word)) <= $width) { $line .= ' ' . $word; }
            else { $lines[] = $line; $line = $word; }
        }
        if ($line !== '') { $lines[] = $line; }
        return $lines ?: [''];
    }

    private static function pdfText(string $value): string
    {
        $value = iconv('UTF-8', 'Windows-1252//TRANSLIT//IGNORE', $value) ?: $value;
        return str_replace(['\\', '(', ')', "\r", "\n"], ['\\\\', '\\(', '\\)', ' ', ' '], $value);
    }
}
