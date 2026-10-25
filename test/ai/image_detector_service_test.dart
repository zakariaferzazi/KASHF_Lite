import 'package:flutter_test/flutter_test.dart';
import 'package:kashf_lite/services/ai/image_detector_service.dart';

void main() {
  group('ImageAiDetectionResult.fromJson', () {
    test('parses AI generated result with Midjourney model', () {
      final json = <String, dynamic>{
        'is_ai_generated': true,
        'ai_percentage': 96,
        'real_percentage': 4,
        'verdict': 'ai_generated',
        'verdict_label_en': 'AI Generated Image',
        'verdict_label_ar': 'صورة مولدة بالذكاء الاصطناعي',
        'ai_model': 'Midjourney v6.1',
        'model_confidence': 92,
        'model_reasoning':
            'Volumetric lighting and hyper-smoothed skin textures typical of Midjourney.',
        'summary_en':
            'High confidence AI generation. Significant synthetic artifacts detected.',
        'summary_ar':
            'درجة ثقة عالية بأن الصورة مولدة بالذكاء الاصطناعي مع رصد ملامح تركيبية.',
        'visual_artifacts': [
          {
            'type': 'skin_texture',
            'description_en':
                'Over-smoothed skin texture lacking natural micro-pores.',
            'description_ar': 'تنعيم مفرط لنسيج البشرة مع غياب المسام الطبيعية.',
            'indicates_ai': true,
          },
          {
            'type': 'lighting',
            'description_en': 'Inconsistent specular catchlights in the eyes.',
            'description_ar': 'انعكاسات ضوئية غير متناسقة في بؤبؤ العينين.',
            'indicates_ai': true,
          },
        ],
        'technical_details': {
          'lighting_assessment': 'Directional mismatch observed',
          'texture_assessment': 'Synthetic smoothing without natural noise',
          'geometry_assessment': 'Subtle perspective warping',
        },
      };

      final resultEn = ImageAiDetectionResult.fromJson(json, language: 'en');
      expect(resultEn.isAiGenerated, isTrue);
      expect(resultEn.aiPercentage, 96);
      expect(resultEn.realPercentage, 4);
      expect(resultEn.verdict, 'ai_generated');
      expect(resultEn.verdictLabel, 'AI Generated Image');
      expect(resultEn.aiModel, 'Midjourney v6.1');
      expect(resultEn.modelConfidence, 92);
      expect(resultEn.modelReasoning, contains('Volumetric lighting'));
      expect(resultEn.summary, contains('High confidence'));
      expect(resultEn.artifacts.length, 2);
      expect(resultEn.artifacts.first.type, 'skin_texture');
      expect(resultEn.artifacts.first.indicatesAi, isTrue);
      expect(resultEn.artifacts.first.description, contains('Over-smoothed'));
      expect(resultEn.technicalDetails['lighting_assessment'],
          'Directional mismatch observed');

      final resultAr = ImageAiDetectionResult.fromJson(json, language: 'ar');
      expect(resultAr.verdictLabel, 'صورة مولدة بالذكاء الاصطناعي');
      expect(resultAr.summary, contains('درجة ثقة عالية'));
      expect(resultAr.artifacts.first.description, contains('تنعيم مفرط'));
    });

    test('parses authentic camera photo result', () {
      final json = <String, dynamic>{
        'is_ai_generated': false,
        'ai_percentage': 5,
        'real_percentage': 95,
        'verdict': 'human_real',
        'verdict_label_en': 'Authentic Camera Photograph',
        'verdict_label_ar': 'صورة فوتوغرافية حقيقية',
        'ai_model': 'Not Applicable (Real Camera Photo)',
        'model_confidence': 95,
        'model_reasoning':
            'Consistent optical Bayer sensor noise and physically accurate light falloff.',
        'summary_en':
            'The image exhibits authentic optical characteristics and natural human imperfections.',
        'summary_ar': 'تُظهر الصورة خصائص بصرية حقيقية ونمط ضوضاء عدسة طبيعي.',
        'visual_artifacts': [
          {
            'type': 'sensor_noise',
            'description_en':
                'Natural ISO sensor grain evenly distributed across shadow areas.',
            'description_ar': 'حبيبات ضوضاء ISO طبيعية موزعة بانتظام.',
            'indicates_ai': false,
          },
        ],
        'technical_details': {
          'lighting_assessment': 'Physically accurate environmental reflection',
          'texture_assessment': 'Genuine micro-textures present',
          'geometry_assessment': 'Standard camera focal length distortion',
        },
      };

      final result = ImageAiDetectionResult.fromJson(json, language: 'en');
      expect(result.isAiGenerated, isFalse);
      expect(result.aiPercentage, 5);
      expect(result.realPercentage, 95);
      expect(result.verdict, 'human_real');
      expect(result.aiModel, 'Not Applicable (Real Camera Photo)');
      expect(result.artifacts.first.indicatesAi, isFalse);
    });

    test('handles fallback when fields are missing or unexpected types', () {
      final json = <String, dynamic>{
        'ai_percentage': '78.5',
      };

      final result = ImageAiDetectionResult.fromJson(json, language: 'en');
      expect(result.aiPercentage, 79);
      expect(result.realPercentage, 21);
      expect(result.isAiGenerated, isTrue);
      expect(result.scannedModel, ImageAiDetectorService.kModelId);
    });
  });

  group('ImageAiDetectorService configuration', () {
    test('uses google/gemini-2.5-flash-lite', () {
      expect(
        ImageAiDetectorService.kModelId,
        'google/gemini-2.5-flash-lite',
      );
    });
  });
}
