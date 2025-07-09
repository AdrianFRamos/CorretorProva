import cv2
import numpy as np
from typing import List, Dict, Tuple, Any
import logging

class GabaritoProcessorMelhorado:
    def __init__(self):
        self.opcoes = ['A', 'B', 'C', 'D', 'E']
        self.threshold_preenchimento = 0.6  # 60% preenchido para considerar marcado
        
        # Parâmetros ajustados para o gabarito real
        self.circle_detection_params = {
            'dp': 1,
            'min_dist': 20,  # Distância mínima entre círculos
            'param1': 50,
            'param2': 30,
            'min_radius': 8,   # Raio mínimo ajustado
            'max_radius': 25   # Raio máximo ajustado
        }
        
        # Configuração para layout de duas colunas
        self.layout_config = {
            'duas_colunas': True,
            'margem_coluna': 0.1,  # 10% de margem para separar colunas
            'questoes_por_coluna': None  # Será calculado dinamicamente
        }

    def preprocessar_imagem(self, image):
        """
        Pré-processamento melhorado para o gabarito real
        """
        # Converter para escala de cinza
        if len(image.shape) == 3:
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        else:
            gray = image.copy()
        
        # Redimensionar se muito grande (otimização)
        height, width = gray.shape
        if width > 1500:
            scale = 1500 / width
            new_width = int(width * scale)
            new_height = int(height * scale)
            gray = cv2.resize(gray, (new_width, new_height))
        
        # Aplicar filtro bilateral para reduzir ruído mantendo bordas
        gray = cv2.bilateralFilter(gray, 9, 75, 75)
        
        # Equalização de histograma adaptativa para melhorar contraste
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
        gray = clahe.apply(gray)
        
        # Aplicar filtro gaussiano suave
        gray = cv2.GaussianBlur(gray, (3, 3), 0)
        
        return gray

    def detectar_circulos_melhorado(self, image):
        """
        Detecção de círculos melhorada para o gabarito real
        """
        gray = self.preprocessar_imagem(image)
        
        # Detectar círculos usando HoughCircles com parâmetros ajustados
        circles = cv2.HoughCircles(
            gray,
            cv2.HOUGH_GRADIENT,
            dp=self.circle_detection_params['dp'],
            minDist=self.circle_detection_params['min_dist'],
            param1=self.circle_detection_params['param1'],
            param2=self.circle_detection_params['param2'],
            minRadius=self.circle_detection_params['min_radius'],
            maxRadius=self.circle_detection_params['max_radius']
        )
        
        if circles is not None:
            circles = np.round(circles[0, :]).astype("int")
            
            # Filtrar círculos muito próximos (duplicatas)
            circles_filtrados = self._filtrar_circulos_duplicados(circles)
            
            # Converter para formato padrão
            circulos_formatados = []
            for (x, y, r) in circles_filtrados:
                circulos_formatados.append({
                    'centro': (x, y),
                    'raio': r,
                    'x': x,
                    'y': y
                })
            
            return circulos_formatados
        
        return []

    def _filtrar_circulos_duplicados(self, circles, min_distance=15):
        """
        Remove círculos muito próximos (duplicatas)
        """
        if len(circles) == 0:
            return circles
        
        circles_filtrados = []
        
        for circle in circles:
            x, y, r = circle
            muito_proximo = False
            
            for circle_existente in circles_filtrados:
                x_exist, y_exist, r_exist = circle_existente
                distancia = np.sqrt((x - x_exist)**2 + (y - y_exist)**2)
                
                if distancia < min_distance:
                    muito_proximo = True
                    break
            
            if not muito_proximo:
                circles_filtrados.append(circle)
        
        return np.array(circles_filtrados)

    def organizar_circulos_duas_colunas(self, circulos):
        """
        Organiza círculos considerando layout de duas colunas
        """
        if not circulos:
            return []
        
        # Separar círculos por posição X (colunas)
        circulos_ordenados = sorted(circulos, key=lambda c: c['x'])
        
        # Encontrar divisão entre colunas
        x_positions = [c['x'] for c in circulos_ordenados]
        x_medio = (min(x_positions) + max(x_positions)) / 2
        
        # Separar em duas colunas
        coluna_esquerda = [c for c in circulos_ordenados if c['x'] < x_medio]
        coluna_direita = [c for c in circulos_ordenados if c['x'] >= x_medio]
        
        # Organizar cada coluna por posição Y (linhas)
        coluna_esquerda = sorted(coluna_esquerda, key=lambda c: c['y'])
        coluna_direita = sorted(coluna_direita, key=lambda c: c['y'])
        
        # Agrupar círculos por linha em cada coluna
        linhas_esquerda = self._agrupar_por_linha(coluna_esquerda)
        linhas_direita = self._agrupar_por_linha(coluna_direita)
        
        # Combinar as duas colunas
        todas_linhas = []
        
        # Adicionar linhas da coluna esquerda
        for linha in linhas_esquerda:
            if len(linha) == 5:  # Deve ter exatamente 5 opções
                todas_linhas.append(linha)
        
        # Adicionar linhas da coluna direita
        for linha in linhas_direita:
            if len(linha) == 5:  # Deve ter exatamente 5 opções
                todas_linhas.append(linha)
        
        return todas_linhas

    def _agrupar_por_linha(self, circulos, tolerancia_y=20):
        """
        Agrupa círculos que estão na mesma linha (mesmo Y aproximado)
        """
        if not circulos:
            return []
        
        linhas = []
        circulos_restantes = circulos.copy()
        
        while circulos_restantes:
            # Pegar o primeiro círculo como referência
            circulo_ref = circulos_restantes[0]
            y_ref = circulo_ref['y']
            
            # Encontrar todos os círculos na mesma linha
            linha_atual = []
            novos_restantes = []
            
            for circulo in circulos_restantes:
                if abs(circulo['y'] - y_ref) <= tolerancia_y:
                    linha_atual.append(circulo)
                else:
                    novos_restantes.append(circulo)
            
            # Ordenar linha por posição X
            linha_atual = sorted(linha_atual, key=lambda c: c['x'])
            
            if len(linha_atual) >= 3:  # Pelo menos 3 círculos para ser uma linha válida
                linhas.append(linha_atual)
            
            circulos_restantes = novos_restantes
        
        return linhas

    def mapear_questoes_opcoes_melhorado(self, linhas_circulos):
        """
        Mapeia círculos para questões e opções considerando duas colunas
        """
        questoes_mapeadas = {}
        
        for i, linha in enumerate(linhas_circulos):
            numero_questao = i + 1
            questoes_mapeadas[numero_questao] = {}
            
            # Mapear cada círculo da linha para uma opção
            for j, circulo in enumerate(linha[:5]):  # Máximo 5 opções
                if j < len(self.opcoes):
                    opcao = self.opcoes[j]
                    questoes_mapeadas[numero_questao][opcao] = circulo
        
        return questoes_mapeadas

    def verificar_preenchimento_melhorado(self, image, circulo):
        """
        Verificação melhorada de preenchimento do círculo
        """
        gray = self.preprocessar_imagem(image)
        
        x, y, r = circulo['centro'][0], circulo['centro'][1], circulo['raio']
        
        # Criar máscara circular
        mask = np.zeros(gray.shape, dtype=np.uint8)
        cv2.circle(mask, (x, y), r-2, 255, -1)  # Círculo um pouco menor para evitar bordas
        
        # Extrair região do círculo
        regiao_circulo = cv2.bitwise_and(gray, gray, mask=mask)
        pixels_circulo = regiao_circulo[mask > 0]
        
        if len(pixels_circulo) == 0:
            return False
        
        # Calcular estatísticas da região
        media_intensidade = np.mean(pixels_circulo)
        mediana_intensidade = np.median(pixels_circulo)
        
        # Determinar se está preenchido baseado na intensidade
        # Círculos preenchidos têm intensidade menor (mais escuros)
        threshold_intensidade = 120  # Ajustável
        
        # Considerar preenchido se a maioria dos pixels for escura
        pixels_escuros = np.sum(pixels_circulo < threshold_intensidade)
        total_pixels = len(pixels_circulo)
        
        porcentagem_escura = pixels_escuros / total_pixels
        
        return porcentagem_escura >= self.threshold_preenchimento

    def detectar_marcacoes_melhorado(self, image):
        """
        Detecção completa de marcações com melhorias
        """
        try:
            # Detectar círculos
            circulos = self.detectar_circulos_melhorado(image)
            
            if not circulos:
                return {'erro': 'Nenhum círculo detectado na imagem'}
            
            # Organizar círculos considerando duas colunas
            linhas_circulos = self.organizar_circulos_duas_colunas(circulos)
            
            if not linhas_circulos:
                return {'erro': 'Não foi possível organizar os círculos em linhas válidas'}
            
            # Mapear questões e opções
            questoes_mapeadas = self.mapear_questoes_opcoes_melhorado(linhas_circulos)
            
            # Verificar preenchimento de cada círculo
            marcacoes_detectadas = {}
            
            for numero_questao, opcoes in questoes_mapeadas.items():
                marcacoes_questao = []
                
                for opcao, circulo in opcoes.items():
                    if self.verificar_preenchimento_melhorado(image, circulo):
                        marcacoes_questao.append(opcao)
                
                marcacoes_detectadas[numero_questao] = marcacoes_questao
            
            return marcacoes_detectadas
            
        except Exception as e:
            return {'erro': f'Erro no processamento: {str(e)}'}

    def processar_gabarito_completo_melhorado(self, image):
        """
        Processamento completo melhorado do gabarito
        """
        try:
            # Detectar marcações
            marcacoes = self.detectar_marcacoes_melhorado(image)
            
            if 'erro' in marcacoes:
                return marcacoes
            
            # Analisar marcações
            resultado = {
                'marcacoes_detectadas': marcacoes,
                'questoes_multiplas': [],
                'questoes_em_branco': [],
                'questoes_validas': {},
                'total_questoes_processadas': len(marcacoes),
                'metodo_processamento': 'melhorado_duas_colunas'
            }
            
            for numero_questao, opcoes_marcadas in marcacoes.items():
                if len(opcoes_marcadas) == 0:
                    resultado['questoes_em_branco'].append(numero_questao)
                elif len(opcoes_marcadas) > 1:
                    resultado['questoes_multiplas'].append(numero_questao)
                else:
                    resultado['questoes_validas'][numero_questao] = opcoes_marcadas[0]
            
            return resultado
            
        except Exception as e:
            return {'erro': f'Erro no processamento completo: {str(e)}'}

    def debug_visualizar_deteccao_melhorado(self, image, output_path=None):
        """
        Visualização melhorada para debug
        """
        try:
            # Detectar círculos
            circulos = self.detectar_circulos_melhorado(image)
            
            # Criar imagem de debug
            debug_image = image.copy()
            
            # Desenhar todos os círculos detectados
            for i, circulo in enumerate(circulos):
                x, y, r = circulo['centro'][0], circulo['centro'][1], circulo['raio']
                
                # Verificar se está preenchido
                preenchido = self.verificar_preenchimento_melhorado(image, circulo)
                
                # Cor baseada no preenchimento
                cor = (0, 255, 0) if preenchido else (0, 0, 255)  # Verde se preenchido, vermelho se não
                
                # Desenhar círculo
                cv2.circle(debug_image, (x, y), r, cor, 2)
                cv2.circle(debug_image, (x, y), 2, cor, -1)
                
                # Adicionar número do círculo
                cv2.putText(debug_image, str(i), (x-10, y-r-10), 
                           cv2.FONT_HERSHEY_SIMPLEX, 0.5, cor, 1)
            
            # Organizar em linhas e adicionar informações
            linhas_circulos = self.organizar_circulos_duas_colunas(circulos)
            questoes_mapeadas = self.mapear_questoes_opcoes_melhorado(linhas_circulos)
            
            # Adicionar texto com informações
            info_text = [
                f"Circulos detectados: {len(circulos)}",
                f"Linhas organizadas: {len(linhas_circulos)}",
                f"Questoes mapeadas: {len(questoes_mapeadas)}"
            ]
            
            for i, text in enumerate(info_text):
                cv2.putText(debug_image, text, (10, 30 + i*25), 
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            
            if output_path:
                cv2.imwrite(output_path, debug_image)
            
            return debug_image
            
        except Exception as e:
            print(f"Erro na visualização de debug: {e}")
            return image

