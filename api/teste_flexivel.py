#!/usr/bin/env python3
"""
Script de teste para o sistema flexível de correção de gabaritos
"""

import requests
import json
import base64
from PIL import Image, ImageDraw, ImageFont

def criar_gabarito_flexivel(num_questoes=10):
    """
    Cria um gabarito com número flexível de questões
    """
    # Criar imagem base
    height = 100 + (num_questoes * 40)  # Altura dinâmica
    img = Image.new('RGB', (600, height), 'white')
    draw = ImageDraw.Draw(img)
    
    # Título
    draw.text((50, 30), f"GABARITO TESTE - {num_questoes} QUESTÕES", fill='black')
    
    # Desenhar questões
    start_y = 80
    for questao in range(1, num_questoes + 1):
        y = start_y + (questao - 1) * 40
        
        # Número da questão
        draw.text((20, y), f"{questao:02d}", fill='black')
        
        # Opções A, B, C, D, E
        opcoes = ['A', 'B', 'C', 'D', 'E']
        for i, opcao in enumerate(opcoes):
            x = 80 + i * 40
            
            # Desenhar círculo
            draw.ellipse([x-10, y-10, x+10, y+10], outline='black', width=2)
            
            # Preencher alguns círculos como exemplo
            if questao <= 5:  # Primeiras 5 questões marcadas
                if (questao == 1 and opcao == 'A') or \
                   (questao == 2 and opcao == 'B') or \
                   (questao == 3 and opcao == 'C') or \
                   (questao == 4 and opcao == 'D') or \
                   (questao == 5 and opcao == 'E'):
                    draw.ellipse([x-8, y-8, x+8, y+8], fill='black')
            elif questao == 6:  # Questão com múltiplas marcações
                if opcao in ['A', 'B']:
                    draw.ellipse([x-8, y-8, x+8, y+8], fill='black')
            # Questão 7 em branco (sem marcação)
            
            # Letra da opção
            draw.text((x-3, y+15), opcao, fill='black')
    
    # Salvar
    img_path = f"/home/ubuntu/gabarito-api/gabarito_teste_{num_questoes}q.png"
    img.save(img_path)
    return img_path

def testar_validacao_flexivel():
    """
    Testa validação com diferentes números de questões
    """
    print("🔍 Testando validação flexível...")
    
    casos_teste = [
        # Caso 1: 5 questões
        {
            "nome": "5 questões",
            "gabarito": {"1": "A", "2": "B", "3": "C", "4": "D", "5": "E"}
        },
        # Caso 2: 10 questões
        {
            "nome": "10 questões",
            "gabarito": {str(i): ['A', 'B', 'C', 'D', 'E'][i % 5] for i in range(1, 11)}
        },
        # Caso 3: 20 questões
        {
            "nome": "20 questões",
            "gabarito": {str(i): ['A', 'B', 'C', 'D', 'E'][i % 5] for i in range(1, 21)}
        },
        # Caso 4: Gabarito inválido
        {
            "nome": "Gabarito inválido",
            "gabarito": {"1": "X", "3": "A"}  # Questão 2 faltando, opção inválida
        }
    ]
    
    for caso in casos_teste:
        print(f"\\n  Testando: {caso['nome']}")
        try:
            response = requests.post("http://localhost:5000/api/gabarito/validar-gabarito", 
                                   json={"gabarito_oficial": caso['gabarito']})
            
            if response.status_code == 200:
                data = response.json()
                print(f"    ✅ Válido: {data['valido']}")
                print(f"    📊 Total questões: {data['total_questoes']}")
                if not data['valido']:
                    print(f"    ❌ Erros: {len(data['erros'])}")
            else:
                print(f"    ❌ Erro HTTP: {response.status_code}")
        except Exception as e:
            print(f"    ❌ Erro: {e}")

def testar_correcao_flexivel():
    """
    Testa correção com diferentes números de questões
    """
    print("\\n🎯 Testando correção flexível...")
    
    casos_teste = [5, 10, 15]
    
    for num_questoes in casos_teste:
        print(f"\\n  Testando com {num_questoes} questões...")
        
        # Criar gabarito de teste
        img_path = criar_gabarito_flexivel(num_questoes)
        print(f"    📄 Gabarito criado: {img_path}")
        
        # Gabarito oficial
        gabarito_oficial = {str(i): ['A', 'B', 'C', 'D', 'E'][i % 5] for i in range(1, num_questoes + 1)}
        
        try:
            # Converter imagem para base64
            with open(img_path, 'rb') as f:
                img_data = base64.b64encode(f.read()).decode('utf-8')
            
            # Testar endpoint simplificado
            payload = {
                "gabarito_oficial": gabarito_oficial,
                "imagem": img_data
            }
            
            response = requests.post("http://localhost:5000/api/gabarito/corrigir-simples", 
                                   json=payload)
            
            if response.status_code == 200:
                data = response.json()
                if data['success']:
                    resultado = data['resultado']
                    print(f"    ✅ Sucesso!")
                    print(f"    📊 Acertos: {resultado['acertos']}/{resultado['total_questoes']}")
                    print(f"    📈 Porcentagem: {resultado['porcentagem_acerto']}%")
                    print(f"    📝 Nota: {resultado['nota']}/10")
                    
                    problemas = data['problemas']
                    if any(problemas.values()):
                        print(f"    ⚠️  Problemas detectados:")
                        if problemas['questoes_multiplas'] > 0:
                            print(f"        - Múltiplas marcações: {problemas['questoes_multiplas']}")
                        if problemas['questoes_em_branco'] > 0:
                            print(f"        - Em branco: {problemas['questoes_em_branco']}")
                        if problemas['questoes_nao_detectadas'] > 0:
                            print(f"        - Não detectadas: {problemas['questoes_nao_detectadas']}")
                else:
                    print(f"    ❌ Falha: {data['error']}")
            else:
                print(f"    ❌ Erro HTTP: {response.status_code}")
                print(f"    Resposta: {response.text}")
        
        except Exception as e:
            print(f"    ❌ Erro: {e}")

def testar_template_atualizado():
    """
    Testa o template atualizado
    """
    print("\\n📋 Testando template atualizado...")
    
    try:
        response = requests.get("http://localhost:5000/api/gabarito/gabarito-template")
        
        if response.status_code == 200:
            data = response.json()
            print("    ✅ Template obtido com sucesso!")
            print(f"    📝 Opções por questão: {data['opcoes_por_questao']}")
            print(f"    🔤 Opções válidas: {data['opcoes']}")
            print("    📖 Observações:")
            for obs in data['observacoes']:
                print(f"        - {obs}")
        else:
            print(f"    ❌ Erro HTTP: {response.status_code}")
    
    except Exception as e:
        print(f"    ❌ Erro: {e}")

def main():
    """
    Executa todos os testes do sistema flexível
    """
    print("🚀 Testando Sistema Flexível de Correção de Gabaritos\\n")
    
    # Verificar se a API está rodando
    try:
        response = requests.get("http://localhost:5000/api/gabarito/health", timeout=2)
        if response.status_code != 200:
            print("⚠️  API não está respondendo corretamente")
            print("💡 Execute: python src/main.py")
            return
        print("✅ API está funcionando\\n")
    except:
        print("❌ API não está rodando")
        print("💡 Execute: python src/main.py")
        return
    
    # Executar testes
    testar_template_atualizado()
    testar_validacao_flexivel()
    testar_correcao_flexivel()
    
    print("\\n🎉 Testes do sistema flexível concluídos!")

if __name__ == "__main__":
    main()

