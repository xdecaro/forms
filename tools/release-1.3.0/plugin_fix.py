#!/usr/bin/env python3
from pathlib import Path
import re,sys
p=Path(sys.argv[1])
t=p.read_text()
# Include form title in the token map used by subjects, HTML and additional emails.
t=t.replace("$tokenValues = $values + ['form_id'=>(string) $form['id']];", "$tokenValues = $values + ['form_id'=>(string) $form['id'], 'form_title'=>(string) $form['title']];",1)
# Global Reply-To fallback is used when a per-email value is not configured and no user reply address is available.
t=t.replace("                if (!filter_var($replyTo, FILTER_VALIDATE_EMAIL) && filter_var($userEmail, FILTER_VALIDATE_EMAIL)) {\n                    $replyTo = $userEmail;\n                }", "                if (!filter_var($replyTo, FILTER_VALIDATE_EMAIL) && filter_var($userEmail, FILTER_VALIDATE_EMAIL)) {\n                    $replyTo = $userEmail;\n                }\n                if (!filter_var($replyTo, FILTER_VALIDATE_EMAIL)) {\n                    $replyTo = trim((string) $params->get('default_reply_to_email',''));\n                }",1)
t=t.replace("                $replyTo = $this->replaceTokens((string) ($userCfg['reply_to'] ?? ''), $tokenValues, $reference, $paymentRef, $submissionId, $allText);\n                if (filter_var($replyTo, FILTER_VALIDATE_EMAIL)) { $mailer->addReplyTo($replyTo, $this->replaceTokens((string) ($userCfg['reply_name'] ?? ''), $tokenValues, $reference, $paymentRef, $submissionId, $allText)); }", "                $replyTo = $this->replaceTokens((string) ($userCfg['reply_to'] ?? ''), $tokenValues, $reference, $paymentRef, $submissionId, $allText);\n                if (!filter_var($replyTo, FILTER_VALIDATE_EMAIL)) { $replyTo = trim((string) $params->get('default_reply_to_email','')); }\n                $replyName = $this->replaceTokens((string) ($userCfg['reply_name'] ?? ''), $tokenValues, $reference, $paymentRef, $submissionId, $allText);\n                if ($replyName === '') { $replyName = trim((string) $params->get('default_reply_to_name','')); }\n                if (filter_var($replyTo, FILTER_VALIDATE_EMAIL)) { $mailer->addReplyTo($replyTo, $replyName); }",1)
# Replace the short country list with the full ISO-3166 alpha-2 set. Joomla/PHP intl supplies localized display names; codes remain the stable fallback.
pat=re.compile(r"    private function countryOptions\(\): string\n    \{.*?\n    \}\n\n    private function italianRegionOptions",re.S)
method=r'''    private function countryOptions(): string
    {
        $codes = preg_split('/\s+/', trim('AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW BY BZ CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW')) ?: [];
        $tag = str_replace('-', '_', $this->getApplication()->getLanguage()->getTag());
        $fallback = ['IT'=>'Italia','BE'=>'Belgio','FR'=>'Francia','DE'=>'Germania','ES'=>'Spagna','GB'=>'Regno Unito','US'=>'Stati Uniti','PE'=>'Perù'];
        $html = '';
        foreach ($codes as $code) {
            $name = $fallback[$code] ?? $code;
            if (class_exists('Locale')) {
                $localized = \Locale::getDisplayRegion('-' . $code, $tag);
                if (is_string($localized) && trim($localized) !== '' && strtoupper($localized) !== $code) { $name = $localized; }
            }
            $html .= '<option value="' . htmlspecialchars($name, ENT_QUOTES, 'UTF-8') . '" data-code="' . $code . '"></option>';
        }
        return $html;
    }

    private function italianRegionOptions'''
t,n=pat.subn(method,t,count=1)
if n!=1: raise RuntimeError('countryOptions method not found')
p.write_text(t)
print('Forms plugin final fixes applied')
