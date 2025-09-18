#!/bin/bash

# Script para gerar todas as versões possíveis de APK
# Criado para o projeto Lince Inspeções

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# Verificar se estamos no diretório correto
if [ ! -f "pubspec.yaml" ]; then
    error "Este script deve ser executado na raiz do projeto Flutter!"
    exit 1
fi

# Criar diretório de builds se não existir
BUILD_DIR="builds/$(date +'%Y%m%d_%H%M%S')"
mkdir -p "$BUILD_DIR"

log "Iniciando build de todas as versões de APK..."
log "Versão atual: $(grep 'version:' pubspec.yaml | cut -d' ' -f2)"
log "Diretório de build: $BUILD_DIR"

# Limpar builds anteriores
log "Limpando builds anteriores..."
flutter clean
flutter pub get

echo ""
log "=========================================="
log "          BUILDS DE DESENVOLVIMENTO"
log "=========================================="

# 1. Debug APK (padrão para desenvolvimento)
log "🔧 Gerando Debug APK..."
if flutter build apk --debug; then
    cp build/app/outputs/flutter-apk/app-debug.apk "$BUILD_DIR/lince_inspecoes_debug.apk"
    success "Debug APK gerado: $BUILD_DIR/lince_inspecoes_debug.apk"
else
    error "Falha ao gerar Debug APK"
fi

# 2. Profile APK (para testes de performance)
log "📊 Gerando Profile APK..."
if flutter build apk --profile; then
    cp build/app/outputs/flutter-apk/app-profile.apk "$BUILD_DIR/lince_inspecoes_profile.apk"
    success "Profile APK gerado: $BUILD_DIR/lince_inspecoes_profile.apk"
else
    error "Falha ao gerar Profile APK"
fi

echo ""
log "=========================================="
log "           BUILDS DE PRODUÇÃO"
log "=========================================="

# 3. Release APK (produção padrão)
log "🚀 Gerando Release APK..."
if flutter build apk --release; then
    cp build/app/outputs/flutter-apk/app-release.apk "$BUILD_DIR/lince_inspecoes_release.apk"
    success "Release APK gerado: $BUILD_DIR/lince_inspecoes_release.apk"
else
    error "Falha ao gerar Release APK"
fi

# 4. Release APK Split por ABI (menor tamanho)
log "📦 Gerando Release APK Split por ABI..."
if flutter build apk --release --split-per-abi; then
    # Copiar todos os APKs gerados com split
    for apk in build/app/outputs/flutter-apk/app-*-release.apk; do
        if [ -f "$apk" ]; then
            filename=$(basename "$apk")
            cp "$apk" "$BUILD_DIR/lince_inspecoes_${filename}"
            success "APK Split gerado: $BUILD_DIR/lince_inspecoes_${filename}"
        fi
    done
else
    error "Falha ao gerar Release APK Split"
fi

echo ""
log "=========================================="
log "           BUILDS ESPECIAIS"
log "=========================================="

# 5. APK com obfuscação (mais seguro)
log "🔒 Gerando Release APK com obfuscação..."
if flutter build apk --release --obfuscate --split-debug-info=build/debug-info; then
    cp build/app/outputs/flutter-apk/app-release.apk "$BUILD_DIR/lince_inspecoes_release_obfuscated.apk"
    success "APK Obfuscado gerado: $BUILD_DIR/lince_inspecoes_release_obfuscated.apk"
else
    warning "Falha ao gerar APK com obfuscação (pode não ser suportado)"
fi

# 6. APK otimizado para diferentes densidades
log "🎯 Gerando APK otimizado para diferentes densidades..."
if flutter build apk --release --target-platform android-arm64; then
    cp build/app/outputs/flutter-apk/app-release.apk "$BUILD_DIR/lince_inspecoes_release_arm64.apk"
    success "APK ARM64 gerado: $BUILD_DIR/lince_inspecoes_release_arm64.apk"
else
    warning "Falha ao gerar APK ARM64"
fi

echo ""
log "=========================================="
log "              RELATÓRIO FINAL"
log "=========================================="

# Gerar relatório
REPORT_FILE="$BUILD_DIR/build_report.txt"
{
    echo "RELATÓRIO DE BUILD - $(date)"
    echo "=================================="
    echo "Projeto: $(grep 'name:' pubspec.yaml | cut -d' ' -f2)"
    echo "Versão: $(grep 'version:' pubspec.yaml | cut -d' ' -f2)"
    echo "Build Time: $(date +'%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "ARQUIVOS GERADOS:"
    echo "----------------------------------"
    ls -lh "$BUILD_DIR"/*.apk 2>/dev/null || echo "Nenhum APK encontrado"
    echo ""
    echo "TAMANHOS DOS ARQUIVOS:"
    echo "----------------------------------"
    du -h "$BUILD_DIR"/*.apk 2>/dev/null || echo "Nenhum APK encontrado"
} > "$REPORT_FILE"

log "📋 Relatório salvo em: $REPORT_FILE"

# Mostrar resumo
echo ""
success "=========================================="
success "           BUILD CONCLUÍDO!"
success "=========================================="
log "📁 Todos os APKs foram salvos em: $BUILD_DIR"
log "📋 Relatório detalhado: $REPORT_FILE"

# Contar arquivos gerados
APK_COUNT=$(ls -1 "$BUILD_DIR"/*.apk 2>/dev/null | wc -l)
log "📦 Total de APKs gerados: $APK_COUNT"

echo ""
log "TIPOS DE APK GERADOS:"
log "• Debug APK - Para desenvolvimento e testes"
log "• Profile APK - Para análise de performance"
log "• Release APK - Para produção (universal)"
log "• Release APK Split - Para produção (otimizado por arquitetura)"
log "• Release APK Obfuscado - Para produção (mais seguro)"
log "• Release APK ARM64 - Para dispositivos ARM64"

echo ""
log "PRÓXIMOS PASSOS:"
log "1. Para desenvolvimento: use lince_inspecoes_debug.apk"
log "2. Para testes de performance: use lince_inspecoes_profile.apk"
log "3. Para produção: use lince_inspecoes_release.apk ou os splits"
log "4. Para máxima segurança: use lince_inspecoes_release_obfuscated.apk"

echo ""
success "Script executado com sucesso! ✨"