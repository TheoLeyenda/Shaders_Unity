﻿Shader "TestShader/Toon/Water"
{
    Properties
    {	
		_DepthGradientShallow("Depth Gradient Shallow", Color) = (0.325, 0.807, 0.971, 0.725) // Color del agua mas cerca de su superficie.
		_DepthGradientDeep("Depth Gradient Deep", Color) = (0.086, 0.407, 1, 0.749) // Color del agua con profundidad.
		_DepthMaxDistance("Depth Maximum Distance", Float) = 1 // Variable que controla el maximo de gradiente de la profundidad del agua.

		_SurfaceNoise("Surface Noise", 2D) = "white" {} // Textura de ruido para simular el flujo del agua en la superficie.
		_SurfaceNoiseCutoff("Surface Noise Cutoff", Range(0, 1)) = 0.777 // Variable entre el 0 y el 1 para controlar la aparicion de la espuma en la superficie.

		_FoamMinDistance("Foam Minimum Distance", Float) = 0.04 //Minima cantidad de espuma que se puede generar en la costa.
		_FoamMaxDistance("Foam Maximum Distance", Float) = 0.4 // Maxima cantidad de espuma que se puede generar en la costa.

		_SurfaceNoiseScroll("Surface Noise Scroll Amount", Vector) = (0.03, 0.03, 0, 0) //Vector de direccion y velocidad del movimiento del agua.
		_SurfaceDistortion("Surface Distortion", 2D) = "white" {} //Textura de distorcion que utilizaremos para generar una sensacion aleatoria a la hora de mover la espuma del agua.
		_SurfaceDistortionAmount("Surface Distortion Amount", Range(0, 1)) = 0.27 // Valor que representa que tanto se distorcionara el movimiento de la espuma.
		_FoamColor("Foam Color", Color) = (1,1,1,1) // Color de la espuma.
    }
    SubShader
    {
        Pass
        {
			//Haremos que el shader tenga transparencia para que simule mejor el agua.
			Tags
			{
				"Queue" = "Transparent"
			}
			Blend SrcAlpha OneMinusSrcAlpha
			ZWrite Off
			//-----------------------------------------------//

			CGPROGRAM
			#define SMOOTHSTEP_AA 0.01
			#pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

			float4 alphaBlend(float4 top, float4 bottom)
			{
				float3 color = (top.rgb * top.a) + (bottom.rgb * (1 - top.a));
				float alpha = top.a + bottom.a * (1 - top.a);

				return float4(color, alpha);
			}			

            struct appdata
            {
				float3 normal : NORMAL; // Datos para calcular las normales de la espuma.
				float4 uv : TEXCOORD0; // Dato para calcular el pixel actual de las texturas.
                float4 vertex : POSITION;
            };

            struct v2f
            {
				float3 viewNormal : NORMAL;  // Datos para calcular las normales de la espuma.
				float2 noiseUV : TEXCOORD0; // Dato para calcular el pixel actual de la textura de ruido que utilizaremos para simular la espuma en el agua.
				float2 distortUV : TEXCOORD1; //Dato para calcular el pixel actual de la textura de distorcion.
                float4 vertex : SV_POSITION;
				float4 screenPosition : TEXCOORD2; //Dato para calcular la posicion del pixel actual que se esta renderizando asi poder poner el pixel
												   //de profundidad por encima.
            };

			//Propiedades declaradas dentro del shader para poder ser usadas.
			float4 _DepthGradientShallow;
			float4 _DepthGradientDeep;
			float _DepthMaxDistance;
			sampler2D _CameraDepthTexture; //Variable para acceder a la textura de profundidad de la camara.
			sampler2D _SurfaceNoise;
			float4 _SurfaceNoise_ST;
			float _SurfaceNoiseCutoff;
			//float _FoamDistance; // REMPLAZADO POR LAS DOS LINEAS DE ABAJO
			float _FoamMaxDistance;
			float _FoamMinDistance;
			float2 _SurfaceNoiseScroll;
			sampler2D _SurfaceDistortion;
			float4 _SurfaceDistortion_ST;
			float _SurfaceDistortionAmount;
			sampler2D _CameraNormalsTexture;
			float4 _FoamColor;
			//---------------------------------------------------------------//

            v2f vert (appdata v)
            {
                v2f o;

                o.vertex = UnityObjectToClipPos(v.vertex);
				o.screenPosition = ComputeScreenPos(o.vertex); //Computamos la posicion del pixel de profundidad.
				o.noiseUV = TRANSFORM_TEX(v.uv, _SurfaceNoise); //Computamos el pixel de la textura de ruido.
				o.distortUV = TRANSFORM_TEX(v.uv, _SurfaceDistortion); // Computamos el pixel de la textura de distorcion.
				o.viewNormal = COMPUTE_VIEW_NORMAL; //Computamos la normal del pixel para hacer una espuma uniforme.
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
				//Proceso la profundidad del pixel en funcion a la posicion de la camara, si movemos la camara veremos como el gradiente de la profundidad del agua tambien se mueve.
				float existingDepth01 = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPosition)).r;
				float existingDepthLinear = LinearEyeDepth(existingDepth01); 
				//--------------------------------------------------------------------//

				//Generamos una diferencia entre el pixel de profundidad generado por la textura de profundidad de la camara y la posicion en w del pixel actual 
				//para poder determinar que tan profunda se deveria ver el agua en escala de grises.
				float depthDifference = existingDepthLinear - i.screenPosition.w;
				//-------------------------------------------------------------------//

				//Generamos el color interpolado utilizando el depthDifference antes calculado y el color 
				//_DepthGradientShallow que representa el color del agua cerca de la superficie (orillas) y 
				//el color _DepthGradientDeep que representa el color del agua en la parte donde su profundidad es alta.
				float waterDepthDifference01 = saturate(depthDifference / _DepthMaxDistance);
				float4 waterColor = lerp(_DepthGradientShallow, _DepthGradientDeep, waterDepthDifference01);
				//------------------------------------------------------------------------------//

				//Generamos la distorcion de la espuma utilizando el _SurfaceDistortion y el _SurfaceDistortionAmount
				float2 distortSample = (tex2D(_SurfaceDistortion, i.distortUV).xy * 2 - 1) * _SurfaceDistortionAmount;
				//------------------------------------------------------------------------------//

				//Utilizamos el _SurfaceNoiseScroll y movemos la textura del agua para generar una sensacion de flujo en el agua.
				float2 noiseUV = float2((i.noiseUV.x + _Time.y * _SurfaceNoiseScroll.x) + distortSample.x, (i.noiseUV.y + _Time.y * _SurfaceNoiseScroll.y) + distortSample.y);
				//---------------------------------------------------------------------------------//

				//Calculamos el surfaceNoiseSample que representara la "espuma" que se genera en el agua y que representa el flujo de esta
				//Utilizando la textura de ruido _SurfaceNoise y el noiseUV.
				float surfaceNoiseSample = tex2D(_SurfaceNoise, noiseUV).r; 
				//-------------------------------------------------------------------------------//

				//Utilizamos las normales de la camara para poder generar una espuma uniforme en el shader y que no se vea pixelada.
				float3 existingNormal = tex2Dproj(_CameraNormalsTexture, UNITY_PROJ_COORD(i.screenPosition));
				float3 normalDot = saturate(dot(existingNormal, i.viewNormal));
				//----------------------------------------------------------------------------------------------------//

				// Generamos la espuma en la orilla utilizando el _FoamMaxDistance y el _FoamMinDistance
				float foamDistance = lerp(_FoamMaxDistance, _FoamMinDistance, normalDot);
				float foamDepthDifference01 = saturate(depthDifference / foamDistance);
				float surfaceNoiseCutoff = foamDepthDifference01 * _SurfaceNoiseCutoff;
				//------------------------------------------------------------------------------------//

				//Recortamos la espuma que se genera en el agua utilizando el surfaceNoiseCutoff para que la generacion de espuma se vea aleatoria y natural.
				float surfaceNoise = smoothstep(surfaceNoiseCutoff - SMOOTHSTEP_AA, surfaceNoiseCutoff + SMOOTHSTEP_AA, surfaceNoiseSample);
				//----------------------------------------------------------------------------------------------------------------------------//

				//Utilizamos el _FoamColor para darle color a la espuma
				float4 surfaceNoiseColor = _FoamColor;
				surfaceNoiseColor.a *= surfaceNoise;
				//---------------------------------------------------//

				//Retorno el color del pixel actual y genero un alphaBlend para que si el pixel se trata de espuma este tome el color de _FoamColor.
				return alphaBlend(surfaceNoiseColor, waterColor);
				//--------------------------------------------------//
            }
            ENDCG
        }
    }
}