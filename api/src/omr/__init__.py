"""Pacote OMR: pipeline de leitura e correção de cartões-resposta.

Módulos:
- quality:    validação da imagem recebida (nitidez, iluminação, resolução)
- preprocess: normalização de iluminação, detecção da folha, correção de perspectiva
- detector:   localização das bolhas (por contornos, com fallback de grade matemática)
- classifier: classificação de cada questão com nível de confiança
- pipeline:   orquestra as etapas e monta o resultado estruturado
"""

from .pipeline import CorrecaoPipeline, LayoutProva

__all__ = ['CorrecaoPipeline', 'LayoutProva']
