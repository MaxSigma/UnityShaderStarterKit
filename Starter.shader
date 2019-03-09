Shader "Templates/Uber"{

Templates:
projection
lighting
toon lighting
water
rim
foliage/ sss
scrolling uv
noise texture
cubemap
holographic
milk glass

    // Var Name , Display name, Type, Default Value
	Properties{

		_MainTex    ("Texture", 2D)         = "white" {}
        _NormalMap  ("Normal", 2D)          = "bump" {}
        _CubeMap    ("CubeMap", Cube)      = "white" {}


        _Skalar     ("Skalar", float)       = 2
        _Factor     ("Factor", Range(0,1))  = 1
        _Color      ("Color",  Color)       = (1,1,1,1)
        _Vector     ("Vector", Vector)      = (1,1,1,1)

	}

	SubShader{

        Tags { "RenderType"="Transparent" "RenderType"="Transparent" "DisableBatching"="True"}

        LOD 100
        Blend One One
        Blend SrcAlpha OneMinusSrcAlpha

        ZTest Off
        ZWrite Off
        Cull Off
         
		Pass{

			CGPROGRAM

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"


			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

        #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight                  
        #pragma shader_feature _NORMALMAP

	       struct appdata{

                float4 vertex   : POSITION;
                float3 normal   : NORMAL;
                float4 tangent  : TANGENT;
                float2 uv       : TEXCOORD0;


            };

            struct v2f{

                float4 vertex : SV_POSITION;
                float3 worldNormal: NORMAL;
                float4 screenPosition : TEXCOORD0;
                float2 uv: TEXCOORD1;
                float4 worldPos: TEXCOORD2;
                float3x3 tangentToWorld: TEXCOORD3;

            };


			sampler2D _MainTex;
            sampler2D _Normal;
            sampler2D _Structure;
            samplerCUBE _CubeMap;

			float4 _MainTex_ST;
            float4 _Color;
            float  _RimPower;
            float  _Cut;


		v2f vert (appdata v){
        
            v2f o;
    
            o.vertex = UnityObjectToClipPos(v.vertex);
            o.worldPos= mul(unity_ObjectToWorld,v.vertex);
            o.worldNormal = UnityObjectToWorldNormal(v.normal);
            o.uv=v.uv;

            float3 tangent= normalize(  mul(float4(v.tangent.xyz, 0.0), unity_ObjectToWorld).xyz );
            o.tangentToWorld =float3x3(tangent.rgb, normalize(cross(o.worldNormal.rgb,tangent.rgb)* v.tangent.w ), o.worldNormal.rgb);

            o.screenPosition = ComputeScreenPos(o.vertex);

            return o;
        }


		fixed4 frag (v2f i) : SV_Target{


            // unity_AmbientSky unity_AmbientEquator unity_AmbientGround

            float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenPosition);

            float3 n = UnpackNormal (tex2D (_BumpMap, i.worldPos.xz*3)).rgb;
            float upDot= dot(normalize(normalRefc), normalize(_WorldSpaceLightPos0))*0.5+0.5;

            float3 viewDir=normalize(i.worldPos-_WorldSpaceCameraPos);
            float2 screenPosition = (i.screenPosition.xy/i.screenPosition.w);

            // Cut out
            clip(p-_Cut);

            // Rim / Fresnel Effect
            float rim= pow(1-abs(dot(viewDir,normal)),_RimPower);

            // Get reflection cube map (may need to generated lighting data)
             half4 skyData = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, viewDirRefl);
             half3 skyColor = DecodeHDR (skyData, unity_SpecCube0_HDR);



                UnityIndirect ind;
                ind.diffuse = 0;
                ind.specular = 0;
                

                UnityLight l;
        
                l.color = _LightColor0.rgb;
                l.dir = _WorldSpaceLightPos0.xyz;
                l.ndotl = LambertTerm (normal, l.dir);


                // Lighting
                fixed shadow = SHADOW_ATTENUATION(i);

                half3 emission=BRDF1_Unity_PBS(albedo.rgb,half3(1.0,1.0,1.0), 1-_metallic, 1-_roughness, normal, -viewDir, l, ind )*shadow;


            return float4(col*1.5,length(col)*3);

            }


			ENDCG
		}
	}


    Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }
            Blend [_SrcBlend] One
            Fog { Color (0,0,0,0) } // in additive pass fog should be black
            ZWrite Off
            ZTest LEqual

            CGPROGRAM
            #pragma target 3.0
            // GLES2.0 temporarily disabled to prevent errors spam on devices without textureCubeLodEXT
            #pragma exclude_renderers gles

            // -------------------------------------

            
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature ___ _DETAIL_MULX2
            #pragma shader_feature _PARALLAXMAP
            
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog

            #pragma vertex vertAdd
            #pragma fragment fragAdd
            #include "UnityStandardCoreForward.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Shadow rendering pass
        Pass{

             Name "ShadowCaster"
             Tags{ "LightMode" = "ShadowCaster" }
             ZWrite On ZTest LEqual

             Cull Off
            
            CGPROGRAM
            #pragma target 3.0
            // TEMPORARY: GLES2.0 temporarily disabled to prevent errors spam on devices without textureCubeLodEXT
            #pragma exclude_renderers gles
            
            // -------------------------------------
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma multi_compile_shadowcaster


             #pragma vertex vert
             #pragma fragment frag
             #pragma multi_compile_shadowcaster

             #include "UnityCG.cginc"

             sampler2D _MainTex;
             float3 _sirnic_windDir;
             float _windAmount;

             struct v2f {

                    float2 uv : TEXCOORD0;
                    V2F_SHADOW_CASTER;
                    float4 worldPos : TEXCOORD2;

             };
 
             v2f vert(appdata_full v){

                    v2f o;
                    TRANSFER_SHADOW_CASTER(o) // this has to be BEFORE the transformation!!!

                    o.pos = mul(unity_ObjectToWorld,v.vertex);

                float3 m_transform=float3(sin(o.pos.x+o.pos.z+_Time.z+v.texcoord.x*4)*sin(o.pos.x*2+o.pos.z*3+_Time.y+v.texcoord.x*4),0,0);
                float4 vertex= v.vertex+float4(mul(unity_WorldToObject, m_transform).xyz,1.0)*_windAmount*0.5* v.color.r;

                    o.pos = UnityObjectToClipPos(vertex);
                    o.uv = v.texcoord;
                    o.worldPos= mul(unity_ObjectToWorld,vertex);

                    return o;
             }

             float _cutOut;

             float4 frag(v2f i) : SV_Target{

                    float2 uvCoord=i.uv;
                    fixed4 col = tex2D(_MainTex, uvCoord);
               
                    clip(col.a-_cutOut);
                    SHADOW_CASTER_FRAGMENT(i)

             }

             ENDCG
         }
 
 
     
        // ------------------------------------------------------------------
          // Deferred pass
        Pass
        {
            Name "DEFERRED"
            Tags { "LightMode" = "Deferred" }
            Cull Off

            CGPROGRAM
            #pragma target 3.0
            // TEMPORARY: GLES2.0 temporarily disabled to prevent errors spam on devices without textureCubeLodEXT
            #pragma exclude_renderers nomrt gles
            

            // -------------------------------------

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature ___ _DETAIL_MULX2
            #pragma shader_feature _PARALLAXMAP

            #pragma multi_compile ___ UNITY_HDR_ON
            #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
            #pragma multi_compile DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE
            #pragma multi_compile DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON
            
            #pragma vertex vertDeferred
            #pragma fragment fragDeferred

            #include "UnityStandardCore.cginc"

            ENDCG
        }

        // ------------------------------------------------------------------
        // Extracts information for lightmapping, GI (emission, albedo, ...)
        // This pass it not used during regular rendering.
        Pass
        {
            Name "META" 
            Tags { "LightMode"="Meta" }

            Cull Off

            CGPROGRAM
            #pragma vertex vert_meta
            #pragma fragment frag_meta


            #include "UnityStandardMeta.cginc"
            ENDCG
        }
    }




    FallBack "VertexLit"


}
