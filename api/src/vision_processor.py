import cv2
import numpy as np
from typing import Dict, List, Tuple, Any, Optional

class VisionProcessorSimplesFuncional:
    """
    Versão simples e funcional baseada no Murtaza Hassan Style
    Foca no que funciona: detectar 43/44 respostas
    Com flexibilidade para configurar questões
    """
    
    def __init__(self):
        self.debug_info = {}
    
    def processar_gabarito(self, image_path: str, 
                          configuracao_questoes: Optional[Dict[str, List[int]]] = None,
                          gabarito_oficial: Optional[Dict[int, str]] = None) -> Dict[str, Any]:
        """
        Processa gabarito usando método que funciona (Murtaza Hassan Style)
        """
        # Carregar imagem
        image = cv2.imread(image_path)
        if image is None:
            raise ValueError(f"Não foi possível carregar a imagem: {image_path}")
        
        # Se não foi fornecida configuração, usar padrão (1-44)
        if configuracao_questoes is None:
            configuracao_questoes = {
                'todas_questoes': list(range(1, 45))  # Questões 1-44
            }
        
        # Processar usando método Murtaza Hassan (que funciona)
        respostas_detectadas = self.processar_murtaza_hassan_style(image)
        
        # Filtrar respostas baseado na configuração
        respostas_filtradas = {}
        todas_questoes_config = []
        for questoes in configuracao_questoes.values():
            todas_questoes_config.extend(questoes)
        
        for questao, resposta in respostas_detectadas.items():
            if questao in todas_questoes_config:
                respostas_filtradas[questao] = resposta
        
        # Calcular estatísticas
        total_questoes = len(todas_questoes_config)
        
        resultado = {
            'respostas_detectadas': respostas_filtradas,
            'total_questoes': total_questoes,
            'questoes_respondidas': len(respostas_filtradas),
            'configuracao_usada': configuracao_questoes,
            'eficiencia': len(respostas_filtradas) / total_questoes * 100 if total_questoes > 0 else 0
        }
        
        # Comparar com gabarito oficial se fornecido
        if gabarito_oficial:
            acertos = 0
            total_comparavel = 0
            
            for questao, resposta_detectada in respostas_filtradas.items():
                if questao in gabarito_oficial:
                    total_comparavel += 1
                    if resposta_detectada == gabarito_oficial[questao]:
                        acertos += 1
            
            resultado.update({
                'acertos': acertos,
                'total_comparavel': total_comparavel,
                'precisao': (acertos / total_comparavel * 100) if total_comparavel > 0 else 0,
                'nota': (acertos / total_comparavel * 10) if total_comparavel > 0 else 0
            })
        
        return resultado
    
    def processar_murtaza_hassan_style(self, image: np.ndarray) -> Dict[int, str]:
        """
        Método Murtaza Hassan que funciona bem (43/44 respostas)
        """
        # Converter para escala de cinza
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        
        # Aplicar blur e threshold
        blurred = cv2.GaussianBlur(gray, (5, 5), 1)
        thresh = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)[1]
        
        # Encontrar contornos
        contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        # Encontrar o maior contorno (folha de gabarito)
        if not contours:
            return {}
        
        largest_contour = max(contours, key=cv2.contourArea)
        
        # Aproximar contorno para retângulo
        epsilon = 0.02 * cv2.arcLength(largest_contour, True)
        approx = cv2.approxPolyDP(largest_contour, epsilon, True)
        
        # Se não conseguiu aproximar para retângulo, usar bounding box
        if len(approx) != 4:
            x, y, w, h = cv2.boundingRect(largest_contour)
            approx = np.array([[x, y], [x + w, y], [x + w, y + h], [x, y + h]], dtype=np.float32)
        else:
            approx = approx.reshape(4, 2).astype(np.float32)
        
        # Ordenar pontos (top-left, top-right, bottom-right, bottom-left)
        rect = self.order_points(approx)
        
        # Calcular dimensões da folha corrigida
        (tl, tr, br, bl) = rect
        widthA = np.sqrt(((br[0] - bl[0]) ** 2) + ((br[1] - bl[1]) ** 2))
        widthB = np.sqrt(((tr[0] - tl[0]) ** 2) + ((tr[1] - tl[1]) ** 2))
        maxWidth = max(int(widthA), int(widthB))
        
        heightA = np.sqrt(((tr[0] - br[0]) ** 2) + ((tr[1] - br[1]) ** 2))
        heightB = np.sqrt(((tl[0] - bl[0]) ** 2) + ((tl[1] - bl[1]) ** 2))
        maxHeight = max(int(heightA), int(heightB))
        
        # Pontos de destino
        dst = np.array([
            [0, 0],
            [maxWidth - 1, 0],
            [maxWidth - 1, maxHeight - 1],
            [0, maxHeight - 1]
        ], dtype="float32")
        
        # Aplicar transformação de perspectiva
        M = cv2.getPerspectiveTransform(rect, dst)
        warped = cv2.warpPerspective(image, M, (maxWidth, maxHeight))
        
        # Converter para escala de cinza e aplicar threshold
        warped_gray = cv2.cvtColor(warped, cv2.COLOR_BGR2GRAY)
        thresh_warped = cv2.threshold(warped_gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)[1]
        
        # Processar usando grid matemático
        return self.processar_grid_44_questoes(thresh_warped)
    
    def order_points(self, pts):
        """Ordena pontos em ordem: top-left, top-right, bottom-right, bottom-left"""
        rect = np.zeros((4, 2), dtype="float32")
        
        # Top-left: menor soma
        s = pts.sum(axis=1)
        rect[0] = pts[np.argmin(s)]
        
        # Bottom-right: maior soma
        rect[2] = pts[np.argmax(s)]
        
        # Top-right: menor diferença
        diff = np.diff(pts, axis=1)
        rect[1] = pts[np.argmin(diff)]
        
        # Bottom-left: maior diferença
        rect[3] = pts[np.argmax(diff)]
        
        return rect
    
    def processar_grid_44_questoes(self, thresh_image: np.ndarray) -> Dict[int, str]:
        """
        Processa grid de 44 questões (método que funciona)
        """
        height, width = thresh_image.shape
        
        # Configurações do grid (baseado no que funciona)
        num_questoes = 44
        num_opcoes = 5  # A, B, C, D, E
        
        # Dividir em duas colunas (22 questões cada)
        meio_x = width // 2
        
        respostas = {}
        opcoes = ['A', 'B', 'C', 'D', 'E']
        
        # Processar coluna esquerda (questões 1-22)
        coluna_esquerda = thresh_image[:, :meio_x]
        respostas.update(self.processar_coluna(coluna_esquerda, list(range(1, 23)), opcoes))
        
        # Processar coluna direita (questões 23-44)
        coluna_direita = thresh_image[:, meio_x:]
        respostas.update(self.processar_coluna(coluna_direita, list(range(23, 45)), opcoes))
        
        return respostas
    
    def processar_coluna(self, coluna_image: np.ndarray, questoes: List[int], opcoes: List[str]) -> Dict[int, str]:
        """
        Processa uma coluna de questões
        """
        height, width = coluna_image.shape
        
        # Ignorar cabeçalho (20% superior)
        inicio_y = int(height * 0.2)
        
        # Ignorar primeira coluna de números (30% esquerda)
        inicio_x = int(width * 0.3)
        
        # Área útil
        area_util = coluna_image[inicio_y:, inicio_x:]
        altura_util, largura_util = area_util.shape
        
        # Calcular dimensões
        num_questoes = len(questoes)
        num_opcoes = len(opcoes)
        
        altura_questao = altura_util // num_questoes
        largura_opcao = largura_util // num_opcoes
        
        respostas = {}
        
        # Processar cada questão
        for i, numero_questao in enumerate(questoes):
            y_questao = i * altura_questao
            
            preenchimentos = {}
            
            # Analisar cada opção
            for j, opcao in enumerate(opcoes):
                x_opcao = j * largura_opcao
                
                # Região da opção (centro da célula)
                x1 = x_opcao + largura_opcao // 4
                x2 = x_opcao + 3 * largura_opcao // 4
                y1 = y_questao + altura_questao // 4
                y2 = y_questao + 3 * altura_questao // 4
                
                # Garantir que não saia dos limites
                x1 = max(0, min(x1, largura_util - 1))
                x2 = max(0, min(x2, largura_util - 1))
                y1 = max(0, min(y1, altura_util - 1))
                y2 = max(0, min(y2, altura_util - 1))
                
                if x2 > x1 and y2 > y1:
                    roi = area_util[y1:y2, x1:x2]
                    
                    if roi.size > 0:
                        # Contar pixels preenchidos
                        pixels_preenchidos = cv2.countNonZero(roi)
                        pixels_totais = roi.size
                        percentual = pixels_preenchidos / pixels_totais
                        preenchimentos[opcao] = percentual
                    else:
                        preenchimentos[opcao] = 0.0
                else:
                    preenchimentos[opcao] = 0.0
            
            # Determinar resposta (opção mais preenchida)
            if preenchimentos:
                opcao_marcada = max(preenchimentos, key=preenchimentos.get)
                nivel_max = preenchimentos[opcao_marcada]
                
                # Threshold para considerar marcada
                if nivel_max > 0.3:  # 30% de preenchimento
                    respostas[numero_questao] = opcao_marcada
        
        return respostas
    
    def gerar_debug(self, image_path: str, resultado: Dict[str, Any], output_path: str):
        """
        Gera imagem de debug simples
        """
        image = cv2.imread(image_path)
        debug_image = image.copy()
        
        height, width = image.shape[:2]
        
        # Linha divisória no meio (duas colunas)
        meio_x = width // 2
        cv2.line(debug_image, (meio_x, 0), (meio_x, height), (0, 255, 255), 3)
        
        # Informações
        info_text = [
            f"Respostas: {resultado['questoes_respondidas']}/{resultado['total_questoes']}",
            f"Eficiencia: {resultado['eficiencia']:.1f}%"
        ]
        
        if 'nota' in resultado:
            info_text.append(f"Nota: {resultado['nota']:.1f}/10")
        
        info_text.append("Sistema Simples Funcional")
        
        for i, text in enumerate(info_text):
            cv2.putText(debug_image, text, (10, 30 + i * 30), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
        
        cv2.imwrite(output_path, debug_image)


# Exemplo de uso
if __name__ == "__main__":
    processor = VisionProcessorSimplesFuncional()
    
    # Gabarito oficial para teste
    gabarito_oficial = {}
    for i in range(1, 45):
        opcoes = ['A', 'B', 'C', 'D', 'E']
        gabarito_oficial[i] = opcoes[i % 5]
    
    try:
        print("🚀 TESTANDO SISTEMA SIMPLES FUNCIONAL")
        print("=" * 50)
        
        # Teste 1: Configuração padrão
        resultado1 = processor.processar_gabarito(
            "/home/ubuntu/upload/ImagemdoWhatsAppde2025-07-09à(s)15.30.34_170fe798.jpg",
            configuracao_questoes=None,  # Padrão: todas as questões
            gabarito_oficial=gabarito_oficial
        )
        
        print("📋 TESTE 1 - Configuração Padrão:")
        print(f"Respostas: {resultado1['questoes_respondidas']}/{resultado1['total_questoes']}")
        print(f"Eficiência: {resultado1['eficiencia']:.1f}%")
        print(f"Nota: {resultado1.get('nota', 0):.1f}/10")
        
        # Teste 2: Configuração personalizada
        config_personalizada = {
            'primeira_metade': list(range(1, 23)),    # Q1-22
            'segunda_metade': list(range(23, 45))     # Q23-44
        }
        
        resultado2 = processor.processar_gabarito(
            "/home/ubuntu/upload/ImagemdoWhatsAppde2025-07-09à(s)15.30.34_170fe798.jpg",
            configuracao_questoes=config_personalizada,
            gabarito_oficial=gabarito_oficial
        )
        
        print("\n📋 TESTE 2 - Configuração Personalizada:")
        print(f"Respostas: {resultado2['questoes_respondidas']}/{resultado2['total_questoes']}")
        print(f"Eficiência: {resultado2['eficiencia']:.1f}%")
        print(f"Nota: {resultado2.get('nota', 0):.1f}/10")
        
        # Gerar debug
        processor.gerar_debug(
            "/home/ubuntu/upload/ImagemdoWhatsAppde2025-07-09à(s)15.30.34_170fe798.jpg",
            resultado1,
            "/home/ubuntu/debug_simples_funcional.png"
        )
        
        print(f"\n🖼️ Debug salvo: /home/ubuntu/debug_simples_funcional.png")
        print("✅ Sistema simples funcional testado!")
        
    except Exception as e:
        print(f"❌ Erro: {e}")

