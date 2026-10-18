# Copyright © 2026 @APHONlC. All rights reserved.
#
# No copying, modification, distribution, or sale without prior written permission.
# AI/ML ingestion and training are strictly prohibited (TDM opt-out).
#
# See LICENSE.md for full terms and maintenance exceptions.

function is_row(line) {
	return line !~ /^\t/ && index(line, "\t") > 0
}
function row_field(line, n,    parts) {
	split(line, parts, "\t")
	return parts[n]
}
function extract_key(line,    k) {
	if (is_row(line)) return row_field(line, 1)
	k = line
	if (sub(/^\t\["/, "", k)) {
		sub(/"\].*/, "", k)
		return k
	}
	k = line
	if (sub(/^\t/, "", k) && sub(/ = \{.*/, "", k) && k !~ / /) {
		return k
	}
	return ""
}
function extract_version(line,    v) {
	if (is_row(line)) {
		v = row_field(line, 2)
		return v ~ /^[0-9]+$/ ? v + 0 : -1
	}
	v = line
	if (sub(/.*requiredVersion = /, "", v)) {
		sub(/[^0-9].*/, "", v)
		return v + 0
	}
	return -1
}
function extract_display(line,    v) {
	if (is_row(line)) return row_field(line, 3)
	v = line
	if (sub(/.*displayVersion = "/, "", v)) {
		sub(/".*/, "", v)
		return v
	}
	return ""
}
function short_value(line,    v) {
	v = line
	if (is_row(line)) {
		sub(/^[^\t]*\t/, "", v)
		gsub(/\t/, " | ", v)
	} else {
		sub(/^[^=]*= */, "", v)
		sub(/,$/, "", v)
	}
	if (length(v) > 70) v = substr(v, 1, 67) "..."
	return v
}
FNR == NR {
	key = extract_key($0)
	if (key != "") {
		if (!(key in local_line)) local_order[++n] = key
		local_line[key] = $0
		local_ver[key] = extract_version($0)
	} else if (!in_table) {
		header[++h] = $0
	}
	if ($0 ~ / = \{$/) { in_table = 1; footer = "}" }
	if ($0 ~ /\(\[==\[$/) { in_table = 1; footer = "]==])" }
	next
}
{
	key = extract_key($0)
	if (key == "") next
	rver = extract_version($0)
	rdisp = extract_display($0)
	if (!(key in local_line)) {
		local_order[++n] = key
		local_line[key] = $0
		local_ver[key] = rver
		added++
		added_detail[added] = key ": new entry, " (rver >= 0 ? "version " rver " (" rdisp ")" : short_value($0))
		next
	}
	if (local_line[key] == $0) next
	lver = local_ver[key]
	if (lver >= 0 && rver < 0) next
	if (lver >= 0 && rver < lver) next
	old_line = local_line[key]
	local_line[key] = $0
	local_ver[key] = rver
	updated++
	if (rver > lver && lver >= 0)
		updated_detail[updated] = key ": " lver " (" extract_display(old_line) ") -> " rver " (" rdisp ")"
	else
		updated_detail[updated] = key ": " short_value(old_line) " -> " short_value($0)
}
END {
	for (i = 2; i <= n; i++) {
		key_i = local_order[i]
		j = i - 1
		while (j >= 1 && tolower(local_order[j]) > tolower(key_i)) {
			local_order[j + 1] = local_order[j]
			j--
		}
		local_order[j + 1] = key_i
	}
	for (i = 1; i <= h; i++) print header[i]
	for (i = 1; i <= n; i++) print local_line[local_order[i]]
	print footer
	print "ADDED=" added+0 > "/dev/stderr"
	print "UPDATED=" updated+0 > "/dev/stderr"
	for (i = 1; i <= added; i++) print "# + " added_detail[i] > "/dev/stderr"
	for (i = 1; i <= updated; i++) print "# ~ " updated_detail[i] > "/dev/stderr"
}
