import json
from typing import Dict, List, Tuple, Any
from datetime import datetime

class GabaritoValidator:
    def __init__(self):
        self.opcoes_validas = ['A', 'B', 'C', 'D', 'E']
        # Removido total_questoes fixo - será determinado dinamicamente
    
    def validar_gabarito_oficial(self, gabarito_oficial: Dict[str, str]) -> Tuple[bool, List[str], int]:
        """
        Valida se o gabarito oficial está no formato correto
        Retorna: (válido, erros, total_questoes)
        """
        erros = []
        
        # Verificar se é um dicionário
        if not isinstance(gabarito_oficial, dict):
            erros.append("Gabarito oficial deve ser um objeto JSON")
            return False, erros, 0
        
        if not gabarito_oficial:
            erros.append("Gabarito oficial não pode estar vazio")
            return False, erros, 0
        
        # Determinar número de questões baseado nas chaves
        questoes_numericas = []
        for questao in gabarito_oficial.keys():
            try:
                num_questao = int(questao)
                questoes_numericas.append(num_questao)
            except ValueError:
                erros.append(f"Chave '{questao}' não é um número válido")
        
        if not questoes_numericas:
            erros.append("Nenhuma questão válida encontrada")
            return False, erros, 0
        
        # Verificar sequência de questões
        questoes_numericas.sort()
        total_questoes = max(questoes_numericas)
        
        # Verificar se as questões são sequenciais a partir de 1
        for i in range(1, total_questoes + 1):
            questao_str = str(i)
            if questao_str not in gabarito_oficial:
                erros.append(f"Questão {i} não encontrada no gabarito oficial")
            else:
                resposta = gabarito_oficial[questao_str]
                if resposta not in self.opcoes_validas:
                    erros.append(f"Questão {i}: resposta '{resposta}' inválida. Use: {', '.join(self.opcoes_validas)}")
        
        return len(erros) == 0, erros, total_questoes
    
    def calcular_estatisticas_detalhadas(self, resultado_correcao: Dict[str, Any]) -> Dict[str, Any]:
        """
        Calcula estatísticas detalhadas da correção
        """
        detalhes = resultado_correcao.get('detalhes', {})
        total_questoes = resultado_correcao.get('total_questoes', len(detalhes))
        
        # Contadores por status
        contadores = {
            'respondida_correta': 0,
            'respondida_incorreta': 0,
            'multipla_marcacao': 0,
            'em_branco': 0,
            'nao_detectada': 0
        }
        
        # Análise por questão
        for questao, info in detalhes.items():
            status = info.get('status', 'nao_detectada')
            
            if status == 'respondida':
                if info.get('correto', False):
                    contadores['respondida_correta'] += 1
                else:
                    contadores['respondida_incorreta'] += 1
            elif status == 'multipla_marcacao':
                contadores['multipla_marcacao'] += 1
            elif status == 'em_branco':
                contadores['em_branco'] += 1
            else:
                contadores['nao_detectada'] += 1
        
        # Calcular porcentagens
        porcentagens = {
            key: round((valor / total_questoes) * 100, 2) 
            for key, valor in contadores.items()
        }
        
        # Análise de desempenho
        acertos = contadores['respondida_correta']
        tentativas_validas = acertos + contadores['respondida_incorreta']
        
        taxa_acerto_tentativas = round((acertos / tentativas_validas) * 100, 2) if tentativas_validas > 0 else 0
        taxa_deteccao = round(((total_questoes - contadores['nao_detectada']) / total_questoes) * 100, 2)
        
        return {
            'contadores': contadores,
            'porcentagens': porcentagens,
            'taxa_acerto_tentativas': taxa_acerto_tentativas,
            'taxa_deteccao': taxa_deteccao,
            'questoes_problematicas': contadores['multipla_marcacao'] + contadores['em_branco'] + contadores['nao_detectada'],
            'total_questoes': total_questoes
        }
    
    def gerar_relatorio_detalhado(self, resultado_correcao: Dict[str, Any], gabarito_oficial: Dict[str, str]) -> Dict[str, Any]:
        """
        Gera um relatório detalhado da correção
        """
        estatisticas = self.calcular_estatisticas_detalhadas(resultado_correcao)
        
        # Questões por categoria
        questoes_por_categoria = {
            'corretas': [],
            'incorretas': [],
            'multiplas': [],
            'em_branco': [],
            'nao_detectadas': []
        }
        
        detalhes = resultado_correcao.get('detalhes', {})
        
        for questao_str, info in detalhes.items():
            questao_num = int(questao_str)
            status = info.get('status', 'nao_detectada')
            
            if status == 'respondida':
                if info.get('correto', False):
                    questoes_por_categoria['corretas'].append(questao_num)
                else:
                    questoes_por_categoria['incorretas'].append(questao_num)
            elif status == 'multipla_marcacao':
                questoes_por_categoria['multiplas'].append(questao_num)
            elif status == 'em_branco':
                questoes_por_categoria['em_branco'].append(questao_num)
            else:
                questoes_por_categoria['nao_detectadas'].append(questao_num)
        
        # Ordenar listas
        for categoria in questoes_por_categoria.values():
            categoria.sort()
        
        # Análise de padrões de erro
        analise_opcoes = self._analisar_padroes_opcoes(detalhes, gabarito_oficial)
        
        return {
            'timestamp': datetime.now().isoformat(),
            'resumo': {
                'total_questoes': self.total_questoes,
                'acertos': resultado_correcao.get('acertos', 0),
                'erros': resultado_correcao.get('erros', 0),
                'porcentagem_acerto': resultado_correcao.get('porcentagem_acerto', 0)
            },
            'estatisticas': estatisticas,
            'questoes_por_categoria': questoes_por_categoria,
            'analise_opcoes': analise_opcoes,
            'recomendacoes': self._gerar_recomendacoes(estatisticas, questoes_por_categoria)
        }
    
    def _analisar_padroes_opcoes(self, detalhes: Dict[str, Any], gabarito_oficial: Dict[str, str]) -> Dict[str, Any]:
        """
        Analisa padrões nas respostas do aluno
        """
        opcoes_escolhidas = {opcao: 0 for opcao in self.opcoes_validas}
        opcoes_corretas = {opcao: 0 for opcao in self.opcoes_validas}
        
        for questao_str, info in detalhes.items():
            if info.get('status') == 'respondida':
                resposta_aluno = info.get('resposta_aluno')
                resposta_correta = info.get('resposta_correta')
                
                if resposta_aluno in self.opcoes_validas:
                    opcoes_escolhidas[resposta_aluno] += 1
                
                if resposta_correta in self.opcoes_validas:
                    opcoes_corretas[resposta_correta] += 1
        
        return {
            'distribuicao_respostas_aluno': opcoes_escolhidas,
            'distribuicao_gabarito_oficial': opcoes_corretas
        }
    
    def _gerar_recomendacoes(self, estatisticas: Dict[str, Any], questoes_por_categoria: Dict[str, List[int]]) -> List[str]:
        """
        Gera recomendações baseadas na análise
        """
        recomendacoes = []
        
        # Recomendações baseadas na taxa de detecção
        if estatisticas['taxa_deteccao'] < 90:
            recomendacoes.append("Taxa de detecção baixa. Verifique a qualidade da imagem e iluminação.")
        
        # Recomendações baseadas em múltiplas marcações
        if len(questoes_por_categoria['multiplas']) > 5:
            recomendacoes.append("Muitas questões com múltiplas marcações. Oriente o aluno sobre preenchimento correto.")
        
        # Recomendações baseadas em questões em branco
        if len(questoes_por_categoria['em_branco']) > 10:
            recomendacoes.append("Muitas questões em branco. Verifique se o aluno completou a prova.")
        
        # Recomendações baseadas na taxa de acerto
        taxa_acerto = estatisticas['porcentagens']['respondida_correta']
        if taxa_acerto < 30:
            recomendacoes.append("Taxa de acerto muito baixa. Considere revisar o conteúdo com o aluno.")
        elif taxa_acerto > 90:
            recomendacoes.append("Excelente desempenho! Aluno demonstra domínio do conteúdo.")
        
        return recomendacoes
    
    def validar_resultado_processamento(self, resultado: Dict[str, Any]) -> Tuple[bool, List[str]]:
        """
        Valida se o resultado do processamento está consistente
        """
        erros = []
        
        # Verificar campos obrigatórios
        campos_obrigatorios = ['status', 'acertos', 'erros', 'total_questoes', 'detalhes']
        for campo in campos_obrigatorios:
            if campo not in resultado:
                erros.append(f"Campo obrigatório '{campo}' não encontrado")
        
        # Verificar consistência numérica
        if 'acertos' in resultado and 'erros' in resultado and 'total_questoes' in resultado:
            total_calculado = resultado['acertos'] + resultado['erros']
            if total_calculado != resultado['total_questoes']:
                erros.append(f"Inconsistência: acertos ({resultado['acertos']}) + erros ({resultado['erros']}) ≠ total ({resultado['total_questoes']})")
        
        # Verificar detalhes
        if 'detalhes' in resultado and 'total_questoes' in resultado:
            detalhes = resultado['detalhes']
            total_questoes = resultado['total_questoes']
            if len(detalhes) != total_questoes:
                erros.append(f"Número de questões nos detalhes ({len(detalhes)}) ≠ total esperado ({total_questoes})")
        
        return len(erros) == 0, erros

