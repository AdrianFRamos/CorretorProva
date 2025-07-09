from flask import Blueprint, request, jsonify
import os
import cv2
import numpy as np
from PIL import Image
import base64
import io
from werkzeug.utils import secure_filename
from src.vision_processor_melhorado import GabaritoProcessorMelhorado
from src.validator import GabaritoValidator

gabarito_bp = Blueprint('gabarito', __name__)

@gabarito_bp.route('/health', methods=['GET'])
def health_check():
    """
    Endpoint para verificar se a API está funcionando
    """
    return jsonify({
        'status': 'ok',
        'message': 'API de correção de gabaritos funcionando',
        'versao': 'melhorada_v2.0',
        'suporte_duas_colunas': True,
        'questoes_flexiveis': True
    }), 200

@gabarito_bp.route('/corrigir', methods=['POST'])
def corrigir_gabarito():
    """
    Endpoint principal para correção de gabarito (versão completa)
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'Dados não fornecidos'}), 400
        
        if 'gabarito_oficial' not in data:
            return jsonify({'error': 'Gabarito oficial não fornecido'}), 400
        
        if 'imagem' not in data and 'arquivo' not in data:
            return jsonify({'error': 'Imagem ou caminho do arquivo não fornecido'}), 400
        
        gabarito_oficial = data['gabarito_oficial']
        
        # Validar gabarito oficial
        validator = GabaritoValidator()
        valido, erros_validacao, total_questoes = validator.validar_gabarito_oficial(gabarito_oficial)
        
        if not valido:
            return jsonify({
                'error': 'Gabarito oficial inválido',
                'detalhes': erros_validacao
            }), 400
        
        # Processar imagem
        if 'imagem' in data:
            try:
                image_data = base64.b64decode(data['imagem'])
                image = Image.open(io.BytesIO(image_data))
                image_cv = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
            except Exception as e:
                return jsonify({'error': f'Erro ao processar imagem: {str(e)}'}), 400
        else:
            filepath = data['arquivo']
            if not os.path.exists(filepath):
                return jsonify({'error': 'Arquivo não encontrado'}), 404
            image_cv = cv2.imread(filepath)
        
        # Processar gabarito (total_questoes é opcional agora)
        resultado = processar_gabarito(image_cv, gabarito_oficial, total_questoes)
        
        # Validar resultado
        resultado_valido, erros_resultado = validator.validar_resultado_processamento(resultado)
        
        if not resultado_valido:
            return jsonify({
                'warning': 'Resultado pode conter inconsistências',
                'erros_validacao': erros_resultado,
                'resultado': resultado
            }), 200
        
        # Gerar relatório detalhado
        relatorio = validator.gerar_relatorio_detalhado(resultado, gabarito_oficial)
        
        return jsonify({
            'resultado': resultado,
            'relatorio': relatorio,
            'validacao': 'aprovada'
        }), 200
    
    except Exception as e:
        return jsonify({'error': f'Erro interno: {str(e)}'}), 500

@gabarito_bp.route('/corrigir-simples', methods=['POST'])
def corrigir_gabarito_simples():
    """
    Endpoint simplificado para correção - otimizado para integração com frontend
    Agora sem limitação de número de questões
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'Dados não fornecidos'}), 400
        
        # Validar dados obrigatórios
        if 'gabarito_oficial' not in data:
            return jsonify({'error': 'Gabarito oficial não fornecido'}), 400
        
        if 'imagem' not in data:
            return jsonify({'error': 'Imagem não fornecida'}), 400
        
        gabarito_oficial = data['gabarito_oficial']
        
        # Validar gabarito oficial (sem limitação de questões)
        validator = GabaritoValidator()
        valido, erros_validacao, total_questoes = validator.validar_gabarito_oficial(gabarito_oficial)
        
        if not valido:
            return jsonify({
                'success': False,
                'error': 'Gabarito oficial inválido',
                'detalhes': erros_validacao
            }), 400
        
        # Processar imagem (apenas base64 para simplicidade)
        try:
            image_data = base64.b64decode(data['imagem'])
            image = Image.open(io.BytesIO(image_data))
            image_cv = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
        except Exception as e:
            return jsonify({
                'success': False,
                'error': 'Erro ao processar imagem',
                'detalhes': str(e)
            }), 400
        
        # Processar gabarito com processador melhorado
        resultado = processar_gabarito(image_cv, gabarito_oficial)
        
        if resultado['status'] == 'erro':
            return jsonify({
                'success': False,
                'error': resultado['message']
            }), 500
        
        # Resposta simplificada para frontend
        resposta_simples = {
            'success': True,
            'resultado': {
                'acertos': resultado['acertos'],
                'erros': resultado['erros'],
                'total_questoes': resultado['total_questoes'],
                'total_questoes_detectadas': resultado.get('total_questoes_detectadas', 0),
                'porcentagem_acerto': resultado['porcentagem_acerto'],
                'nota': round((resultado['acertos'] / resultado['total_questoes']) * 10, 1) if resultado['total_questoes'] > 0 else 0,
            },
            'problemas': {
                'questoes_multiplas': len(resultado['questoes_multiplas']),
                'questoes_em_branco': len(resultado['questoes_em_branco']),
                'questoes_nao_detectadas': len(resultado['questoes_nao_detectadas'])
            },
            'metodo_processamento': resultado.get('metodo_usado', 'melhorado')
        }
        
        # Adicionar detalhes se solicitado
        if data.get('incluir_detalhes', False):
            resposta_simples['detalhes'] = resultado['detalhes']
            resposta_simples['marcacoes_detectadas'] = resultado['processamento'].get('marcacoes_detectadas', {})
        
        return jsonify(resposta_simples), 200
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Erro interno: {str(e)}'
        }), 500

@gabarito_bp.route('/debug', methods=['POST'])
def debug_deteccao():
    """
    Endpoint para debug - retorna imagem com círculos detectados
    """
    try:
        data = request.get_json()
        
        if not data or 'imagem' not in data:
            return jsonify({'error': 'Imagem não fornecida'}), 400
        
        # Processar imagem
        try:
            image_data = base64.b64decode(data['imagem'])
            image = Image.open(io.BytesIO(image_data))
            image_cv = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
        except Exception as e:
            return jsonify({'error': f'Erro ao processar imagem: {str(e)}'}), 400
        
        # Criar processador e gerar debug
        processor = GabaritoProcessorMelhorado()
        
        # Gerar imagem de debug
        debug_image = processor.debug_visualizar_deteccao_melhorado(image_cv)
        
        # Converter imagem de debug para base64
        _, buffer = cv2.imencode('.png', debug_image)
        debug_base64 = base64.b64encode(buffer).decode('utf-8')
        
        # Obter informações de detecção
        marcacoes = processor.detectar_marcacoes_melhorado(image_cv)
        
        return jsonify({
            'debug_image': debug_base64,
            'marcacoes_detectadas': marcacoes,
            'status': 'sucesso'
        }), 200
    
    except Exception as e:
        return jsonify({'error': f'Erro no debug: {str(e)}'}), 500

@gabarito_bp.route('/validar-gabarito', methods=['POST'])
def validar_gabarito_oficial():
    """
    Endpoint para validar formato do gabarito oficial (sem limitação de questões)
    """
    try:
        data = request.get_json()
        
        if not data or 'gabarito_oficial' not in data:
            return jsonify({'error': 'Gabarito oficial não fornecido'}), 400
        
        validator = GabaritoValidator()
        valido, erros, total_questoes = validator.validar_gabarito_oficial(data['gabarito_oficial'])
        
        return jsonify({
            'valido': valido,
            'erros': erros,
            'total_questoes': total_questoes,
            'opcoes_validas': validator.opcoes_validas,
            'flexivel': True
        }), 200
    
    except Exception as e:
        return jsonify({'error': f'Erro na validação: {str(e)}'}), 500

@gabarito_bp.route('/gabarito-template', methods=['GET'])
def get_gabarito_template():
    """
    Retorna informações sobre o template do gabarito (totalmente flexível)
    """
    template_info = {
        'opcoes_por_questao': 5,
        'opcoes': ['A', 'B', 'C', 'D', 'E'],
        'formato_gabarito_oficial': {
            'exemplo': {
                '1': 'A',
                '2': 'B',
                '3': 'C'
                # ... quantas questões você quiser
            },
            'descricao': 'Objeto JSON com número da questão como chave e letra da resposta como valor. Número de questões totalmente flexível.'
        },
        'observacoes': [
            'O número de questões é TOTALMENTE flexível - defina quantas quiser',
            'As questões devem ser numeradas sequencialmente a partir de 1',
            'Cada questão deve ter uma resposta válida: A, B, C, D ou E',
            'Suporte a layout de duas colunas automaticamente',
            'Sistema melhorado de detecção de círculos'
        ],
        'melhorias_v2': [
            'Detecção melhorada para layout de duas colunas',
            'Pré-processamento avançado de imagem',
            'Sem limitação de número de questões',
            'Melhor tratamento de sombras e reflexos'
        ]
    }
    
    return jsonify(template_info), 200

def processar_gabarito(image, gabarito_oficial, total_questoes=None):
    """
    Função principal para processar o gabarito usando visão computacional melhorada
    """
    try:
        # Inicializar processador melhorado
        processor = GabaritoProcessorMelhorado()
        
        # Processar imagem e detectar marcações
        resultado_processamento = processor.processar_gabarito_completo_melhorado(image)
        
        if 'erro' in resultado_processamento:
            return resultado_processamento
        
        # Extrair informações do processamento
        questoes_validas = resultado_processamento.get('questoes_validas', {})
        questoes_multiplas = resultado_processamento.get('questoes_multiplas', [])
        questoes_em_branco = resultado_processamento.get('questoes_em_branco', [])
        total_questoes_detectadas = resultado_processamento.get('total_questoes_processadas', 0)
        
        # Usar o número de questões do gabarito oficial se fornecido, senão usar o detectado
        if total_questoes is None:
            total_questoes = max(total_questoes_detectadas, len(gabarito_oficial))
        
        # Comparar com gabarito oficial
        acertos = 0
        erros = 0
        detalhes = {}
        
        for numero_questao in range(1, total_questoes + 1):
            numero_str = str(numero_questao)
            
            if numero_questao in questoes_multiplas:
                detalhes[numero_str] = {
                    'status': 'multipla_marcacao',
                    'resposta_aluno': resultado_processamento['marcacoes_detectadas'].get(numero_questao, []),
                    'resposta_correta': gabarito_oficial.get(numero_str, ''),
                    'correto': False
                }
                erros += 1
            elif numero_questao in questoes_em_branco:
                detalhes[numero_str] = {
                    'status': 'em_branco',
                    'resposta_aluno': None,
                    'resposta_correta': gabarito_oficial.get(numero_str, ''),
                    'correto': False
                }
                erros += 1
            elif numero_questao in questoes_validas:
                resposta_aluno = questoes_validas[numero_questao]
                resposta_correta = gabarito_oficial.get(numero_str, '')
                correto = resposta_aluno == resposta_correta
                
                detalhes[numero_str] = {
                    'status': 'respondida',
                    'resposta_aluno': resposta_aluno,
                    'resposta_correta': resposta_correta,
                    'correto': correto
                }
                
                if correto:
                    acertos += 1
                else:
                    erros += 1
            else:
                # Questão não detectada
                detalhes[numero_str] = {
                    'status': 'nao_detectada',
                    'resposta_aluno': None,
                    'resposta_correta': gabarito_oficial.get(numero_str, ''),
                    'correto': False
                }
                erros += 1
        
        # Calcular estatísticas
        porcentagem_acerto = (acertos / total_questoes) * 100 if total_questoes > 0 else 0
        
        return {
            'status': 'sucesso',
            'acertos': acertos,
            'erros': erros,
            'total_questoes': total_questoes,
            'total_questoes_detectadas': total_questoes_detectadas,
            'porcentagem_acerto': round(porcentagem_acerto, 2),
            'questoes_multiplas': questoes_multiplas,
            'questoes_em_branco': questoes_em_branco,
            'questoes_nao_detectadas': [int(k) for k, v in detalhes.items() if v['status'] == 'nao_detectada'],
            'detalhes': detalhes,
            'processamento': resultado_processamento,
            'metodo_usado': 'processador_melhorado'
        }
        
    except Exception as e:
        return {
            'status': 'erro',
            'message': f'Erro no processamento: {str(e)}',
            'acertos': 0,
            'erros': 0,
            'detalhes': {}
        }

