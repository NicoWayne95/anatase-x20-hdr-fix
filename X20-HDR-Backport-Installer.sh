#!/usr/bin/env bash
# Xbox Ally X20 / Anatase 2026: ABI-kompatibler DisplayID/HDR-Backport.
# --build:   Nur im Fedora Space; erzeugt eine gepruefte .so.3 im Downloads-Ordner.
# --install: Nur auf Anatase-HOST, explizit mit sudo; aktiviert den Loader-Override.
# --rollback: Entzieht dem Override die Aktivierung, ohne die Originaldatei zu beruehren.

set -Eeuo pipefail

SOURCE_URL="https://gitlab.freedesktop.org/emersion/libdisplay-info/-/releases/0.3.0/downloads/libdisplay-info-0.3.0.tar.xz"
SOURCE_SHA="6ae77cd937f9cf7d1321d35c116062c4911e8447010a6a713ac4286f7a9d5987"
PANEL_SHA="5f36d25b456adefa41e1ea6571dfd0198207f0027606f50c330c7c9493017202"
EDID_PATH="/sys/class/drm/card1-eDP-1/edid"
STAGE_NAME="X20-HDR-Backport-Stage"
DEST_DIR="/var/lib/x20-hdr-backport"
CONF_FILE="/etc/ld.so.conf.d/00-x20-hdr-backport.conf"
LIB_NAME="libdisplay-info.so.0.3.0"

PATCH_ORDER=(84e8da3 788c056 d535192 34b3635 4713505 7324cca 73ab82d 73ec53d)
declare -A PATCH_SHA=(
    [84e8da3]="05762ddd8c5a55e5106c17dd18a3ae86c65e397831b644c80f36e55e373b35b4"
    [788c056]="7e8dc61939919ff62d3d627477f18a417952f84872d0d737a6e1c288d5a5fc92"
    [d535192]="1678a5cee13367d02002b2e084a6d8c75ced10c51760de79abc6789b589de131"
    [34b3635]="141f2aa10fcec0cef0ae66d5ab0cb92a95cb9704ab698218f3a47d327b76a7f1"
    [4713505]="888564a7dba5430ffbc983229b37b23a6c88b765e52010d0e5eb5bc1c9262480"
    [7324cca]="ef0eb85b64aafc1d259e9ecf93812d816c8b344daf021f9efdcd494c94fd3216"
    [73ab82d]="2da5231897f3b60027fbb1a3a6b5f853d243c75b90bb0abba5a2fc3e524c7825"
    [73ec53d]="1cade72a7aa60cc1413114ba7fffabf84d63ef4e3d85bb28fd6731d37bcfa61f"
)

say() { printf '\n>>> %s\n' "$*"; }
fail() { printf '\nABBRUCH: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'USAGE'
Xbox Ally X20: HDR-Backport fuer Anatase (libdisplay-info 0.3.0)

  bash X20-HDR-Backport-Installer.sh --build
      In Fedora Space: Quellcode + acht Upstream-Fixes bauen und pruefen.
      Ergebnis wird unter ~/Downloads/X20-HDR-Backport-Stage abgelegt.

  sudo bash X20-HDR-Backport-Installer.sh --install
      Auf dem Anatase-HOST: Bibliothek nach /var/lib kopieren,
      Loader-Konfiguration in /etc anlegen und ldconfig ausfuehren.
      Loescht/ueberschreibt keine Originalbibliotheken in /usr.

  sudo bash X20-HDR-Backport-Installer.sh --rollback
      Auf dem Anatase-HOST: Nur unsere Loader-Konfiguration entfernen.
      Die selbstgebaute Datei bleibt zur Wiederherstellung erhalten.

  bash X20-HDR-Backport-Installer.sh --status
      Aktuelle Loader-Auswahl und KDE-HDR-Status nur lesend anzeigen.

Nach --install und --rollback einmal abmelden und anmelden oder neu starten.
WARNUNG: Die Aktivierung ist systemweit und wird noch nicht automatisch
auf deiner Konsole getestet. Deshalb mit Pruefungen und Rollback abgesichert.
USAGE
}

need() {
    local item
    local -a missing=()
    for item in "$@"; do
        command -v "$item" >/dev/null 2>&1 || missing+=("$item")
    done
    ((${#missing[@]} == 0)) || fail "Fehlende Programme: ${missing[*]}"
}

check_host() {
    [[ $(id -u) -eq 0 ]] || fail "Bitte mit sudo auf dem Anatase-HOST ausfuehren."
    [[ -r /etc/os-release ]] || fail "Betriebssystem nicht erkennbar."
    grep -q '^NAME="Anatase"' /etc/os-release \
        || fail "Das ist nicht der Anatase-HOST. Ein Fedora Space ist kein gueltiges Installationsziel."
    need rpm ldconfig getent sha256sum install grep
    local installed version
    # Fedora kann x86_64 und i686 parallel installiert haben. Daher jede
    # Paketversion separat pruefen statt sie ohne Trennzeichen zu verketten.
    installed=$(rpm -q --qf '%{VERSION}\n' libdisplay-info 2>/dev/null) \
        || fail "libdisplay-info fehlt auf dem HOST."
    while IFS= read -r version; do
        [[ $version == "0.3.0" ]] \
            || fail "Erwartet wurde 0.3.0, installiert ist ${version:-eine leere Versionsangabe}."
    done <<< "$installed"
}

check_edid() {
    [[ -r "$EDID_PATH" ]] || fail "Display-EDID nicht lesbar: $EDID_PATH"
    local current
    current=$(sha256sum "$EDID_PATH")
    [[ ${current%% *} == "$PANEL_SHA" ]] \
        || fail "Display-EDID hat eine andere Pruefsumme. Dieses Skript ist nur fuer Nicos X20-Pilot-EDID freigegeben."
}

stage_dir_for_user() {
    # Wird auf dem HOST nur fuer den tatsaechlich aufrufenden sudo-Benutzer genutzt.
    [[ -n ${SUDO_USER:-} && $SUDO_USER != root ]] \
        || fail "Aufruf als normaler Benutzer mit sudo erforderlich (SUDO_USER fehlt)."
    local passwd_line operator_home
    passwd_line=$(getent passwd "$SUDO_USER") || fail "Benutzer kann nicht aufgeloest werden."
    operator_home=$(printf '%s\n' "$passwd_line" | cut -d: -f6)
    [[ -n $operator_home && -d $operator_home/Downloads ]] \
        || fail "Downloads-Ordner des Benutzers nicht gefunden."
    STAGE_DIR="$operator_home/Downloads/$STAGE_NAME"
    [[ -d $STAGE_DIR && ! -L $STAGE_DIR ]] || fail "Stage-Verzeichnis fehlt oder ist ein Symlink: $STAGE_DIR"
}

write_probe() {
    local target="$1"
    # Nutzt genau die beiden High-Level-Funktionen, die Plasma auswertet.
    cat > "$target" <<'HDR_C'
#include <libdisplay-info/info.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    FILE *f = fopen(argv[1], "rb");
    if (!f) return 2;
    if (fseek(f, 0, SEEK_END)) { fclose(f); return 2; }
    long size = ftell(f);
    if (size < 128 || fseek(f, 0, SEEK_SET)) { fclose(f); return 2; }
    unsigned char *buf = malloc((size_t)size);
    if (!buf) { fclose(f); return 2; }
    if (fread(buf, 1, (size_t)size, f) != (size_t)size) {
        free(buf); fclose(f); return 2;
    }
    fclose(f);
    struct di_info *info = di_info_parse_edid(buf, (size_t)size);
    free(buf);
    if (!info) return 3;
    const struct di_hdr_static_metadata *hdr = di_info_get_hdr_static_metadata(info);
    const struct di_supported_signal_colorimetry *color = di_info_get_supported_signal_colorimetry(info);
    printf("PQ=%d\n", (int)hdr->pq);
    printf("BT2020=%d\n", (int)color->bt2020_rgb);
    printf("PEAK_NITS=%.1f\n", hdr->desired_content_max_luminance);
    printf("MAXFALL_NITS=%.1f\n", hdr->desired_content_max_frame_avg_luminance);
    di_info_destroy(info);
    return 0;
}
HDR_C
}

compile_probe() {
    local src_dir="$1" build_dir="$2" exe="$3" cfile="$4"
    cc -std=c11 -I"$src_dir/include" "$cfile" -L"$build_dir" \
        -Wl,-rpath,"$build_dir" -ldisplay-info -o "$exe"
}

do_build() {
    [[ $(id -u) -ne 0 ]] || fail "Build bitte als normaler Benutzer, nicht mit sudo."
    if [[ -r /etc/os-release ]] && grep -q '^NAME="Anatase"' /etc/os-release; then
        fail "Bitte zuerst mit dem Befehl 'fedora' einen Fedora Space betreten."
    fi
    need curl tar sha256sum patch sed cc meson ninja nm readelf sort comm awk
    check_edid
    [[ -d "$HOME/Downloads" ]] || fail "Downloads-Ordner fehlt."

    local stage_dir="$HOME/Downloads/$STAGE_NAME"
    [[ ! -e $stage_dir && ! -L $stage_dir ]] \
        || fail "Stage existiert schon: $stage_dir (wird bewusst nicht ueberschrieben)."

    umask 077
    local base work archive baseline patched bbuild pbuild patchid patchfile
    base="${XDG_DATA_HOME:-$HOME/.local/share}/x20-hdr-backport"
    mkdir -p "$base"
    work=$(mktemp -d "$base/build-$(date +%Y%m%d-%H%M%S)-XXXXXXXX")
    archive="$work/libdisplay-info-0.3.0.tar.xz"
    baseline="$work/vanilla"
    patched="$work/mit-backport"
    bbuild="$work/build-vanilla"
    pbuild="$work/build-patched"
    mkdir -p "$baseline" "$patched" "$work/patches"

    say "Quelle von libdisplay-info 0.3.0 herunterladen und pruefen"
    curl --fail --silent --show-error --location --retry 2 --max-time 120 "$SOURCE_URL" -o "$archive"
    printf '%s  %s\n' "$SOURCE_SHA" "$archive" | sha256sum --check --status \
        || fail "Der Quellcode hat die falsche SHA-256-Pruefsumme."
    tar -xJf "$archive" -C "$baseline" --strip-components=1 --no-same-owner
    tar -xJf "$archive" -C "$patched" --strip-components=1 --no-same-owner

    say "Acht offizielle HDR-Commits mit festen SHA-256-Pruefsummen holen"
    for patchid in "${PATCH_ORDER[@]}"; do
        patchfile="$work/patches/$patchid.patch"
        curl --fail --silent --show-error --location --retry 2 --max-time 90 \
            "https://gitlab.freedesktop.org/emersion/libdisplay-info/-/commit/$patchid.patch" \
            -o "$patchfile"
        printf '%s  %s\n' "${PATCH_SHA[$patchid]}" "$patchfile" | sha256sum --check --status \
            || fail "Commit $patchid stimmt nicht mit der geprueften Patch-Datei ueberein."
        # Upstream-Commits enthalten teils spaeter hinzugefuegte Testfixtures,
        # die in 0.3.0 noch nicht existieren. Nur diese Fixture-Diffs auslassen.
        sed '/^diff --git a\/test\/data\//,$d' "$patchfile" \
            | (cd "$patched" && patch -p1 --batch --forward --fuzz=2 --ignore-whitespace -s) \
            || fail "Patch $patchid laesst sich nicht sauber anwenden."
    done

    say "Original 0.3.0 und 0.3.0 mit Backport getrennt kompilieren"
    meson setup "$bbuild" "$baseline" --buildtype=release --prefix="$work/kein-install"
    ninja -C "$bbuild"
    meson setup "$pbuild" "$patched" --buildtype=release --prefix="$work/kein-install"
    ninja -C "$pbuild"

    local original_so="$bbuild/$LIB_NAME"
    local patched_so="$pbuild/$LIB_NAME"
    [[ -f "$original_so" && -f "$patched_so" ]] || fail "Eine der Bibliotheken fehlt."
    readelf -d "$patched_so" | grep -q 'libdisplay-info.so.3' \
        || fail "Falscher SONAME! Muss libdisplay-info.so.3 sein."

    say "ABI pruefen: Alle bisherigen exportierten Symbole muessen vorhanden bleiben"
    nm -D --defined-only "$original_so" | awk 'NF >= 3 {print $3}' | LC_ALL=C sort -u > "$work/symbole-original.txt"
    nm -D --defined-only "$patched_so" | awk 'NF >= 3 {print $3}' | LC_ALL=C sort -u > "$work/symbole-neu.txt"
    comm -23 "$work/symbole-original.txt" "$work/symbole-neu.txt" > "$work/fehlende-symbole.txt"
    [[ ! -s "$work/fehlende-symbole.txt" ]] \
        || fail "ABI-Pruefung nicht bestanden! Fehlende Symbole in $work/fehlende-symbole.txt"
    printf 'ABI-Pruefung: BESTANDEN\n'

    say "Beweis mit Nicos unveraenderter 384-Byte-EDID"
    cp "$EDID_PATH" "$work/original-edid.bin"
    write_probe "$work/hdrprobe.c"
    compile_probe "$baseline" "$bbuild" "$work/vanilla-probe" "$work/hdrprobe.c"
    compile_probe "$patched" "$pbuild" "$work/gepatcht-probe" "$work/hdrprobe.c"
    "$work/vanilla-probe" "$work/original-edid.bin" > "$work/ergebnis-vorher.txt"
    "$work/gepatcht-probe" "$work/original-edid.bin" > "$work/ergebnis-nachher.txt"
    printf '\nOriginal:\n'; cat "$work/ergebnis-vorher.txt"
    printf '\nBackport:\n'; cat "$work/ergebnis-nachher.txt"
    grep -qx 'PQ=0' "$work/ergebnis-vorher.txt" || fail "Original verhielt sich anders als erwartet."
    grep -qx 'BT2020=0' "$work/ergebnis-vorher.txt" || fail "Original zeigt unerwartete BT.2020-Daten."
    grep -qx 'PQ=1' "$work/ergebnis-nachher.txt" || fail "Backport erkennt PQ nicht."
    grep -qx 'BT2020=1' "$work/ergebnis-nachher.txt" || fail "Backport erkennt BT.2020 nicht."

    say "Fertige Bibliothek in den gemeinsam sichtbaren Downloads-Ordner legen"
    mkdir "$stage_dir"
    cp "$patched_so" "$stage_dir/$LIB_NAME"
    (
        cd "$stage_dir"
        sha256sum "$LIB_NAME" > SHA256SUMS
    )
    printf 'BUILD_OK=1\nSOURCE_VERSION=0.3.0\nPANEL_EDID_SHA256=%s\n' "$PANEL_SHA" > "$stage_dir/build-info.txt"
    cp "$work/ergebnis-vorher.txt" "$stage_dir/test-vorher.txt"
    cp "$work/ergebnis-nachher.txt" "$stage_dir/test-nachher.txt"
    say "BUILD ERFOLGREICH. Stage: $stage_dir"
    printf 'Jetzt den Fedora Space mit exit verlassen und erst dann:\n'
    printf '  sudo bash X20-HDR-Backport-Installer.sh --install\n'
}

loader_current() {
    ldconfig -p 2>/dev/null | grep -F 'libdisplay-info.so.3 (' || true
}

do_status() {
    printf '============================================================\n'
    printf 'Xbox Ally X20 / Anatase: HDR Backport Status\n'
    printf '============================================================\n'
    printf 'Konfiguration: %s\n' "$CONF_FILE"
    if [[ -f $CONF_FILE ]]; then
        printf 'Eintrag: '; head -n 1 "$CONF_FILE"
    else
        printf 'Kein Backport-Loader-Override vorhanden.\n'
    fi
    say "Aktuelle dynamische Bibliotheksauswahl"
    loader_current
    if command -v kscreen-doctor >/dev/null 2>&1; then
        say "Plasma-Anzeige (nur gueltig in einer Plasma-Desktopsitzung)"
        kscreen-doctor -o 2>/dev/null | grep -iE 'HDR:|Wide Color Gamut:' || true
    fi
}

do_install() {
    check_host
    check_edid
    stage_dir_for_user
    need cut
    [[ -r "$STAGE_DIR/$LIB_NAME" && -r "$STAGE_DIR/SHA256SUMS" && -r "$STAGE_DIR/build-info.txt" ]] \
        || fail "Unvollstaendige Build-Stage. Zuerst --build im Fedora Space."
    grep -qx 'BUILD_OK=1' "$STAGE_DIR/build-info.txt" || fail "Build-Freigabe fehlt."
    (cd "$STAGE_DIR" && sha256sum --check --status SHA256SUMS) \
        || fail "Bibliothek wurde seit dem Build veraendert!"

    if [[ -e $CONF_FILE || -L $CONF_FILE ]]; then
        if [[ ! -L $CONF_FILE && $(< "$CONF_FILE") == "$DEST_DIR" ]]; then
            say "Backport scheint bereits eingerichtet. --status prueft den Zustand."
            return
        fi
        fail "Konflikt: $CONF_FILE existiert bereits mit anderem Inhalt. Keine Aenderung."
    fi
    [[ ! -e "$DEST_DIR/$LIB_NAME" && ! -L "$DEST_DIR/$LIB_NAME" ]] \
        || fail "Zieldatei existiert bereits. Nicht ueberschreiben."
    local current_loader
    current_loader=$(loader_current)
    [[ -n $current_loader ]] \
        || fail "Originale Host-Bibliothek (.so.3) nicht im System-Loader gefunden."
    if grep -Fq "$DEST_DIR/" <<< "$current_loader"; then
        fail "Loader nutzt bereits eine Backport-Bibliothek; bitte zuerst --status oder --rollback pruefen."
    fi

    printf '\nDieser Schritt beeinflusst die systemweite Auswahl von libdisplay-info.so.3.\n'
    printf 'Es wird keine Datei unter /usr geloescht oder ueberschrieben.\n'
    printf 'Zum Rueckgaengigmachen dient --rollback (ggf. von einer TTY aus).\n'
    local answer
    read -r -p 'Jetzt installieren? Tippe exakt JA: ' answer
    [[ $answer == "JA" ]] || { printf 'Abgebrochen. Keine Installation.\n'; return; }

    install -d -m 0755 "$DEST_DIR"
    install -m 0644 "$STAGE_DIR/$LIB_NAME" "$DEST_DIR/$LIB_NAME"
    ln -s "$LIB_NAME" "$DEST_DIR/libdisplay-info.so.3"
    printf '%s\n' "$DEST_DIR" > "$CONF_FILE"
    chmod 0644 "$CONF_FILE"

    if ! ldconfig; then
        printf 'ldconfig fehlgeschlagen, Config wird rueckgaengig gemacht.\n' >&2
        unlink "$CONF_FILE"
        ldconfig || true
        fail "Installation nicht aktiviert. Die Bibliothek bleibt zur Sicherheit liegen."
    fi
    if ! loader_current | grep -F "$DEST_DIR/" >/dev/null; then
        printf 'Loader bevorzugt die neue Bibliothek nicht. Rollback.\n' >&2
        unlink "$CONF_FILE"
        ldconfig || true
        fail "Aktivierung gescheitert, urspruengliche Auswahl wiederhergestellt."
    fi
    say "INSTALLATION AKTIV. Originaldateien in /usr sind unveraendert."
    printf 'Bitte neu starten und danach --status ausfuehren.\n'
}

do_rollback() {
    [[ $(id -u) -eq 0 ]] || fail "Bitte mit sudo auf dem Anatase-HOST ausfuehren."
    [[ -r /etc/os-release ]] && grep -q '^NAME="Anatase"' /etc/os-release \
        || fail "Rollback ausschliesslich auf dem Anatase-HOST."
    need ldconfig unlink
    if [[ ! -e $CONF_FILE && ! -L $CONF_FILE ]]; then
        printf 'Kein HDR-Backport-Override aktiv. Nichts zu entfernen.\n'
        return
    fi
    [[ ! -L $CONF_FILE && $(< "$CONF_FILE") == "$DEST_DIR" ]] \
        || fail "Config-Datei ist nicht unsere. Keine Aenderung."
    unlink "$CONF_FILE"
    ldconfig || fail "Config entfernt, ldconfig meldet aber einen Fehler. Bitte pruefen."
    say "ROLLBACK ERFOLGREICH. Normale Bibliotheksauswahl wieder aktiv."
    printf 'Die gebaute Bibliothek verbleibt zur Wiederherstellung in %s\n' "$DEST_DIR"
    printf 'Bitte neu starten, damit Plasma die originale Bibliothek neu laedt.\n'
}

main() {
    (($# == 1)) || { usage; fail "Bitte genau einen Modus angeben."; }
    case "$1" in
        --help|-h) usage ;;
        --build) do_build ;;
        --install) do_install ;;
        --rollback) do_rollback ;;
        --status) do_status ;;
        *) usage; fail "Unbekannter Modus: $1" ;;
    esac
}
main "$@"
