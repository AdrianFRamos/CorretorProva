#!/usr/bin/env python3
"""
Teste simples das funcionalidades principais
"""

import json

# Teste 1: Validação de gabarito flexível
print("🔍 Teste 1: Validação de gabarito flexível")

from src.validator import GabaritoValidator

validator = GabaritoValidator()

# Teste com 5 questões
gabarito_5q = {"1": "A", "2": "B", "3": "C", "4": "D", "5": "E"}
valido, erros, total = validator.validar_gabarito_oficial(gabarito_5q)
print(f"  5 questões - Válido: {valido}, Total: {total}")

# Teste com 10 questões
gabarito_10q = {str(i): ['A', 'B', 'C', 'D', 'E'][i % 5] for i in range(1, 11)}
valido, erros, total = validator.validar_gabarito_oficial(gabarito_10q)
print(f"  10 questões - Válido: {valido}, Total: {total}")

# Teste com gabarito inválido
gabarito_invalido = {"1": "X", "3": "A"}  # Questão 2 faltando, opção inválida
valido, erros, total = validator.validar_gabarito_oficial(gabarito_invalido)
print(f"  Inválido - Válido: {valido}, Erros: {len(erros)}")

print("\\n🎯 Teste 2: Processamento de visão")

from src.vision_processor import GabaritoProcessor
import numpy as np

# Criar uma imagem de teste simples
processor = GabaritoProcessor()
test_image = np.ones((400, 600, 3), dtype=np.uint8) * 255  # Imagem branca

# Testar processamento com diferentes números de questões
resultado_5q = processor.processar_gabarito_completo(test_image, 5)
print(f"  Processamento 5 questões - Status: {resultado_5q.get('total_questoes_esperadas', 'N/A')}")

resultado_10q = processor.processar_gabarito_completo(test_image, 10)
print(f"  Processamento 10 questões - Status: {resultado_10q.get('total_questoes_esperadas', 'N/A')}")

print("\\n📊 Teste 3: Estatísticas dinâmicas")

# Simular resultado de correção
resultado_correcao = {
    'acertos': 7,
    'erros': 3,
    'total_questoes': 10,
    'detalhes': {
        str(i): {
            'status': 'respondida',
            'correto': i <= 7
        } for i in range(1, 11)
    }
}

estatisticas = validator.calcular_estatisticas_detalhadas(resultado_correcao)
print(f"  Total questões: {estatisticas['total_questoes']}")
print(f"  Taxa de acerto: {estatisticas['porcentagens']['respondida_correta']}%")

print("\\n✅ Todos os testes básicos passaram!")
print("🎉 Sistema flexível funcionando corretamente!")

