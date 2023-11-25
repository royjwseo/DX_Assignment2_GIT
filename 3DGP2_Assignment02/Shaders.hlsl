struct MATERIAL
{
	float4					m_cAmbient;
	float4					m_cDiffuse;
	float4					m_cSpecular; //a = power
	float4					m_cEmissive;
};

cbuffer cbCameraInfo : register(b1)
{
	matrix		gmtxView : packoffset(c0);
	matrix		gmtxProjection : packoffset(c4);
	float3		gvCameraPosition : packoffset(c8);
};

cbuffer cbGameObjectInfo : register(b2)
{
	matrix		gmtxGameObject : packoffset(c0);
	MATERIAL	gMaterial : packoffset(c4);
	uint		gnTexturesMask : packoffset(c8);

};

cbuffer cbFrameworkInfo : register(b3)
{
	float 		gfCurrentTime;
	float		gfElapsedTime;

};


#include "Light.hlsl"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//#define _WITH_VERTEX_LIGHTING

#define MATERIAL_ALBEDO_MAP			0x01
#define MATERIAL_SPECULAR_MAP		0x02
#define MATERIAL_NORMAL_MAP			0x04
#define MATERIAL_METALLIC_MAP		0x08
#define MATERIAL_EMISSION_MAP		0x10
#define MATERIAL_DETAIL_ALBEDO_MAP	0x20
#define MATERIAL_DETAIL_NORMAL_MAP	0x40



Texture2D gtxtStandardTextures[7] : register(t6);


SamplerState gssWrap : register(s0);

struct VS_STANDARD_INPUT
{
	float3 position : POSITION;
	float2 uv : TEXCOORD;
	float3 normal : NORMAL;
	float3 tangent : TANGENT;
	float3 bitangent : BITANGENT;
};

struct VS_STANDARD_OUTPUT
{
	float4 position : SV_POSITION;
	float3 positionW : POSITION;
	float3 normalW : NORMAL;
	float3 tangentW : TANGENT;
	float3 bitangentW : BITANGENT;
	float2 uv : TEXCOORD;
};

VS_STANDARD_OUTPUT VSStandard(VS_STANDARD_INPUT input)
{
	VS_STANDARD_OUTPUT output;

	output.positionW = (float3)mul(float4(input.position, 1.0f), gmtxGameObject);
	output.normalW = mul(input.normal, (float3x3)gmtxGameObject);
	output.tangentW = (float3)mul(float4(input.tangent, 1.0f), gmtxGameObject);
	output.bitangentW = (float3)mul(float4(input.bitangent, 1.0f), gmtxGameObject);
	output.position = mul(mul(float4(output.positionW, 1.0f), gmtxView), gmtxProjection);
	output.uv = input.uv;

	return(output);
}

float4 PSStandard(VS_STANDARD_OUTPUT input) : SV_TARGET
{
	
	float4 cAlbedoColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cSpecularColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cNormalColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cMetallicColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cEmissionColor = float4(0.0f, 0.0f, 0.0f, 1.0f);


	if (gnTexturesMask & MATERIAL_ALBEDO_MAP) cAlbedoColor = gtxtStandardTextures[0].Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_SPECULAR_MAP) cSpecularColor = gtxtStandardTextures[1].Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_NORMAL_MAP) cNormalColor = gtxtStandardTextures[2].Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_METALLIC_MAP) cMetallicColor = gtxtStandardTextures[3].Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_EMISSION_MAP) cEmissionColor = gtxtStandardTextures[4].Sample(gssWrap, input.uv);


	float4 cIllumination = float4(1.0f, 1.0f, 1.0f, 1.0f);
	float4 cColor = cAlbedoColor + cSpecularColor + cEmissionColor;
	if (gnTexturesMask & MATERIAL_NORMAL_MAP)
	{
		float3 normalW = input.normalW;
		float3x3 TBN = float3x3(normalize(input.tangentW), normalize(input.bitangentW), normalize(input.normalW));
		float3 vNormal = normalize(cNormalColor.rgb * 2.0f - 1.0f); //[0, 1] → [-1, 1]
		normalW = normalize(mul(vNormal, TBN));
		cIllumination = Lighting(input.positionW, normalW);
		cColor = lerp(cColor, cIllumination, 0.5f);
	}

	
	
	return(cColor);
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
struct VS_SKYBOX_CUBEMAP_INPUT
{
	float3 position : POSITION;
};

struct VS_SKYBOX_CUBEMAP_OUTPUT
{
	float3	positionL : POSITION;
	float4	position : SV_POSITION;
};

VS_SKYBOX_CUBEMAP_OUTPUT VSSkyBox(VS_SKYBOX_CUBEMAP_INPUT input)
{
	VS_SKYBOX_CUBEMAP_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.positionL = input.position;

	return(output);
}

TextureCube gtxtSkyCubeTexture[16] : register(t13);
SamplerState gssClamp : register(s1);

float4 PSSkyBox(VS_SKYBOX_CUBEMAP_OUTPUT input) : SV_TARGET
{
	float4 cColor;

// 시간 변수를 실수로 가정하고 1.5초 간격으로 텍스처를 변경합니다.
float currentTime = gfCurrentTime * 1.5f;

// 실수 시간 변수를 이용하여 텍스처를 변경합니다.
int textureIndex = int(currentTime) % 16;
cColor = gtxtSkyCubeTexture[textureIndex].Sample(gssClamp, input.positionL);

return cColor;
}




struct VS_TERRAIN_INPUT
{
	float3 position : POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float2 uv1: TEXCOORD1;
};

struct VS_TERRAIN_OUTPUT
{
	float4 position : SV_POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float2 uv1: TEXCOORD1;
};

VS_TERRAIN_OUTPUT VSTerrain(VS_TERRAIN_INPUT input)
{
	VS_TERRAIN_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.color = input.color;
	output.uv0 = input.uv0;
	output.uv1 = input.uv1;
	return(output);
}
Texture2D gtxtTerrainTexture[3] : register(t29);


float4 PSTerrain(VS_TERRAIN_OUTPUT input) : SV_TARGET
{
	
	float4 cBaseTexColor = gtxtTerrainTexture[0].Sample(gssWrap, input.uv0);
	float4 cDetailTexColor = gtxtTerrainTexture[1].Sample(gssWrap, input.uv1);
	float4 cDetailTexColortwo = gtxtTerrainTexture[2].Sample(gssWrap, input.uv1);

	float4 cColor = saturate(input.color*0.3f+(cBaseTexColor+cDetailTexColor+ cDetailTexColortwo));
	//float4 cColor = cBaseTexColor;
	return(cColor);
}


struct VS_TERRAIN_TESSELLATION_OUTPUT
{
	float3 position : POSITION;
	float3 positionW : POSITION1;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};

VS_TERRAIN_TESSELLATION_OUTPUT VSTerrainTessellation(VS_TERRAIN_INPUT input)
{
	VS_TERRAIN_TESSELLATION_OUTPUT output;

	output.position = input.position;
	output.positionW = mul(float4(input.position, 1.0f), gmtxGameObject).xyz;
	output.color = input.color;
	output.uv0 = input.uv0;
	output.uv1 = input.uv1;

	return(output);
}

struct HS_TERRAIN_TESSELLATION_CONSTANT
{
	float fTessEdges[4] : SV_TessFactor;
	float fTessInsides[2] : SV_InsideTessFactor;
};

struct HS_TERRAIN_TESSELLATION_OUTPUT
{
	float3 position : POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};

struct DS_TERRAIN_TESSELLATION_OUTPUT
{
	float4 position : SV_POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	float4 tessellation : TEXCOORD2;
};

[domain("quad")]
//[partitioning("fractional_even")]
[partitioning("integer")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(25)]
[patchconstantfunc("HSTerrainTessellationConstant")]
[maxtessfactor(64.0f)]
HS_TERRAIN_TESSELLATION_OUTPUT HSTerrainTessellation(InputPatch<VS_TERRAIN_TESSELLATION_OUTPUT, 25> input, uint i : SV_OutputControlPointID)
{
	HS_TERRAIN_TESSELLATION_OUTPUT output;

	output.position = input[i].position;
	output.color = input[i].color;
	output.uv0 = input[i].uv0;
	output.uv1 = input[i].uv1;

	return(output);
}

float CalculateTessFactor(float3 f3Position)
{
	float fDistToCamera = distance(f3Position, gvCameraPosition);
	float s = saturate((fDistToCamera - 10.0f) / (500.0f - 10.0f));

	//return(lerp(64.0f, 1.0f, s));
	return(pow(2, lerp(40.f, 3.f, s)));
}


HS_TERRAIN_TESSELLATION_CONSTANT HSTerrainTessellationConstant(InputPatch<VS_TERRAIN_TESSELLATION_OUTPUT, 25> input)
{
	HS_TERRAIN_TESSELLATION_CONSTANT output;

	//if (gnRenderMode & DYNAMIC_TESSELLATION)
	//{
	//	float3 e0 = 0.5f * (input[0].positionW + input[4].positionW);
	//	float3 e1 = 0.5f * (input[0].positionW + input[20].positionW);
	//	float3 e2 = 0.5f * (input[4].positionW + input[24].positionW);
	//	float3 e3 = 0.5f * (input[20].positionW + input[24].positionW);

	//	output.fTessEdges[0] = CalculateTessFactor(e0);
	//	output.fTessEdges[1] = CalculateTessFactor(e1);
	//	output.fTessEdges[2] = CalculateTessFactor(e2);
	//	output.fTessEdges[3] = CalculateTessFactor(e3);

	//	float3 f3Sum = float3(0.0f, 0.0f, 0.0f);
	//	for (int i = 0; i < 25; i++) f3Sum += input[i].positionW;
	//	float3 f3Center = f3Sum / 25.0f;
	//	output.fTessInsides[0] = output.fTessInsides[1] = CalculateTessFactor(f3Center);
	//}
	//else
	//{
	//	output.fTessEdges[0] = 20.0f;
	//	output.fTessEdges[1] = 20.0f;
	//	output.fTessEdges[2] = 20.0f;
	//	output.fTessEdges[3] = 20.0f;

	//	output.fTessInsides[0] = 20.0f;
	//	output.fTessInsides[1] = 20.0f;
	//}
	float3 e0 = 0.5f * (input[0].positionW + input[4].positionW);
	float3 e1 = 0.5f * (input[0].positionW + input[20].positionW);
	float3 e2 = 0.5f * (input[4].positionW + input[24].positionW);
	float3 e3 = 0.5f * (input[20].positionW + input[24].positionW);

	output.fTessEdges[0] = CalculateTessFactor(e0);
	output.fTessEdges[1] = CalculateTessFactor(e1);
	output.fTessEdges[2] = CalculateTessFactor(e2);
	output.fTessEdges[3] = CalculateTessFactor(e3);

	float3 f3Sum = float3(0.0f, 0.0f, 0.0f);
	for (int i = 0; i < 25; i++) f3Sum += input[i].positionW;
	float3 f3Center = f3Sum / 25.0f;
	output.fTessInsides[0] = output.fTessInsides[1] = CalculateTessFactor(f3Center);
	return(output);
}

void BernsteinCoeffcient5x5(float t, out float fBernstein[5])
{
	float tInv = 1.0f - t;
	fBernstein[0] = tInv * tInv * tInv * tInv;
	fBernstein[1] = 4.0f * t * tInv * tInv * tInv;
	fBernstein[2] = 6.0f * t * t * tInv * tInv;
	fBernstein[3] = 4.0f * t * t * t * tInv;
	fBernstein[4] = t * t * t * t;
}

float3 CubicBezierSum5x5(OutputPatch<HS_TERRAIN_TESSELLATION_OUTPUT, 25> patch, float uB[5], float vB[5])
{
	float3 f3Sum = float3(0.0f, 0.0f, 0.0f);
	f3Sum = vB[0] * (uB[0] * patch[0].position + uB[1] * patch[1].position + uB[2] * patch[2].position + uB[3] * patch[3].position + uB[4] * patch[4].position);
	f3Sum += vB[1] * (uB[0] * patch[5].position + uB[1] * patch[6].position + uB[2] * patch[7].position + uB[3] * patch[8].position + uB[4] * patch[9].position);
	f3Sum += vB[2] * (uB[0] * patch[10].position + uB[1] * patch[11].position + uB[2] * patch[12].position + uB[3] * patch[13].position + uB[4] * patch[14].position);
	f3Sum += vB[3] * (uB[0] * patch[15].position + uB[1] * patch[16].position + uB[2] * patch[17].position + uB[3] * patch[18].position + uB[4] * patch[19].position);
	f3Sum += vB[4] * (uB[0] * patch[20].position + uB[1] * patch[21].position + uB[2] * patch[22].position + uB[3] * patch[23].position + uB[4] * patch[24].position);

	return(f3Sum);
}

[domain("quad")]
DS_TERRAIN_TESSELLATION_OUTPUT DSTerrainTessellation(HS_TERRAIN_TESSELLATION_CONSTANT patchConstant, float2 uv : SV_DomainLocation, OutputPatch<HS_TERRAIN_TESSELLATION_OUTPUT, 25> patch)
{
	DS_TERRAIN_TESSELLATION_OUTPUT output = (DS_TERRAIN_TESSELLATION_OUTPUT)0;

	float uB[5], vB[5];
	BernsteinCoeffcient5x5(uv.x, uB);
	BernsteinCoeffcient5x5(uv.y, vB);

	output.color = lerp(lerp(patch[0].color, patch[4].color, uv.x), lerp(patch[20].color, patch[24].color, uv.x), uv.y);
	output.uv0 = lerp(lerp(patch[0].uv0, patch[4].uv0, uv.x), lerp(patch[20].uv0, patch[24].uv0, uv.x), uv.y);
	output.uv1 = lerp(lerp(patch[0].uv1, patch[4].uv1, uv.x), lerp(patch[20].uv1, patch[24].uv1, uv.x), uv.y);

	float3 position = CubicBezierSum5x5(patch, uB, vB);
	matrix mtxWorldViewProjection = mul(mul(gmtxGameObject, gmtxView), gmtxProjection);
	output.position = mul(float4(position, 1.0f), mtxWorldViewProjection);

	output.tessellation = float4(patchConstant.fTessEdges[0], patchConstant.fTessEdges[1], patchConstant.fTessEdges[2], patchConstant.fTessEdges[3]);

	return(output);
}

float4 PSTerrainTessellation(DS_TERRAIN_TESSELLATION_OUTPUT input) : SV_TARGET
{
	float4 cColor = float4(0.0f, 0.0f, 0.0f, 1.0f);

	/*if (gnRenderMode & (DEBUG_TESSELLATION | DYNAMIC_TESSELLATION))
	{
		if (input.tessellation.w <= 5.0f) cColor = float4(1.0f, 0.0f, 0.0f, 1.0f);
		else if (input.tessellation.w <= 10.0f) cColor = float4(0.0f, 1.0f, 0.0f, 1.0f);
		else if (input.tessellation.w <= 20.0f) cColor = float4(0.0f, 0.0f, 1.0f, 1.0f);
		else if (input.tessellation.w <= 30.0f) cColor = float4(1.0f, 0.0f, 1.0f, 1.0f);
		else if (input.tessellation.w <= 40.0f) cColor = float4(1.0f, 1.0f, 0.0f, 1.0f);
		else if (input.tessellation.w <= 50.0f) cColor = float4(1.0f, 1.0f, 1.0f, 1.0f);
		else if (input.tessellation.w <= 55.0f) cColor = float4(0.2f, 0.2f, 0.72f, 1.0f);
		else if (input.tessellation.w <= 60.0f) cColor = float4(0.5f, 0.75f, 0.75f, 1.0f);
		else cColor = float4(0.87f, 0.17f, 1.0f, 1.0f);
	}
	else
	{
		float4 cBaseTexColor = gtxtTerrainBaseTexture.Sample(gWrapSamplerState, input.uv0);
		float4 cDetailTexColor = gtxtTerrainDetailTexture.Sample(gWrapSamplerState, input.uv1);
		float fAlpha = gtxtTerrainAlphaTexture.Sample(gWrapSamplerState, input.uv0);

		cColor = saturate(lerp(cBaseTexColor, cDetailTexColor, fAlpha));
	}*/

	float4 cBaseTexColor = gtxtTerrainTexture[0].Sample(gssWrap, input.uv0);
	float4 cDetailTexColor = gtxtTerrainTexture[1].Sample(gssWrap, input.uv1);
	float fAlpha = gtxtTerrainTexture[2].Sample(gssWrap, input.uv0);

	cColor = saturate(lerp(cBaseTexColor, cDetailTexColor, fAlpha));
	return(cColor);
}


//
//struct VS_TERRAIN_TESSELLATION_OUTPUT
//{
//	float3 position : POSITION;
//	float3 positionW : POSITION1;
//	float4 color : COLOR;
//	float2 uv0 : TEXCOORD0;
//	float2 uv1 : TEXCOORD1;
//};
//
//VS_TERRAIN_TESSELLATION_OUTPUT VSTerrainTessellation(VS_TERRAIN_INPUT input)
//{
//	VS_TERRAIN_TESSELLATION_OUTPUT output;
//
//	output.position = input.position;
//	output.positionW = mul(float4(input.position, 1.0f), gmtxGameObject).xyz;
//	output.color = input.color;
//	output.uv0 = input.uv0;
//	output.uv1 = input.uv1;
//
//	return(output);
//}
//
//struct HS_TERRAIN_TESSELLATION_CONSTANT
//{
//	float fTessEdges[3] : SV_TessFactor;
//	float fTessInsides : SV_InsideTessFactor;
//};
//
//struct HS_TERRAIN_TESSELLATION_OUTPUT
//{
//	float3 position : POSITION;
//	float4 color : COLOR;
//	float2 uv0 : TEXCOORD0;
//	float2 uv1 : TEXCOORD1;
//};
//
//struct DS_TERRAIN_TESSELLATION_OUTPUT
//{
//	float4 position : SV_POSITION;
//	float4 color : COLOR;
//	float2 uv0 : TEXCOORD0;
//	float2 uv1 : TEXCOORD1;
//	float4 tessellation : TEXCOORD2;
//};
//
//[domain("tri")]
//[partitioning("fractional_odd")]
////[partitioning("integer")]
//[outputtopology("triangle_cw")]
//[outputcontrolpoints(3)]
//[patchconstantfunc("HSTerrainTessellationConstant")]
//[maxtessfactor(64.0f)]
//HS_TERRAIN_TESSELLATION_OUTPUT HSTerrainTessellation(InputPatch<VS_TERRAIN_TESSELLATION_OUTPUT, 3> input, uint i : SV_OutputControlPointID)
//{
//	HS_TERRAIN_TESSELLATION_OUTPUT output;
//
//	output.position = input[i].position;
//	output.color = input[i].color;
//	output.uv0 = input[i].uv0;
//	output.uv1 = input[i].uv1;
//
//	return(output);
//}
//
//float CalculateTessFactor(float3 f3Position)
//{
//	float fDistToCamera = distance(f3Position, gvCameraPosition);
//	float s = saturate((fDistToCamera - 10.0f) / (500.0f - 10.0f));
//
//	return(lerp(64.0f, 1.0f, s));
//	//	return(pow(2, lerp(20.0f, 4.0f, s)));
//}
//float CalculateTessLevel(float3 cameraWorldPos, float3 patchPos, float min, float max, float maxLv)
//{
//	float distance = length(patchPos - cameraWorldPos);
//
//	if (distance < min)
//		return maxLv;
//	if (distance > max)
//		return 1.f;
//
//	float ratio = (distance - min) / (max - min);
//	float level = (maxLv - 1.f) * (1.f - ratio);
//	return level;
//}
//
//HS_TERRAIN_TESSELLATION_CONSTANT HSTerrainTessellationConstant(InputPatch<VS_TERRAIN_TESSELLATION_OUTPUT, 25> input)
//{
//	HS_TERRAIN_TESSELLATION_CONSTANT output;
//
//	float minDistance =1000.f;
//	float maxDistance = 5000.f;
//
//	float3 edge0Pos = (input[1].pos + input[2].pos) / 2.f;
//	float3 edge1Pos = (input[2].pos + input[0].pos) / 2.f;
//	float3 edge2Pos = (input[0].pos + input[1].pos) / 2.f;
//
//	edge0Pos = mul(float4(edge0Pos, 1.f), gmtxGameObject).xyz;
//	edge1Pos = mul(float4(edge1Pos, 1.f), gmtxGameObject).xyz;
//	edge2Pos = mul(float4(edge2Pos, 1.f), gmtxGameObject).xyz;
//
//	float edge0TessLevel = CalculateTessLevel(gvCameraPosition.xyz, edge0Pos, minDistance, maxDistance, 4.f);
//	float edge1TessLevel = CalculateTessLevel(gvCameraPosition.xyz, edge1Pos, minDistance, maxDistance, 4.f);
//	float edge2TessLevel = CalculateTessLevel(gvCameraPosition.xyz, edge2Pos, minDistance, maxDistance, 4.f);
//
//	output.fTessEdges[0] = edge0TessLevel;
//	output.fTessEdges[1] = edge1TessLevel;
//	output.fTessEdges[2] = edge2TessLevel;
//	output.fTessInsides = edge2TessLevel;
//
//	return output;
//}
//
//void BernsteinCoeffcient5x5(float t, out float fBernstein[5])
//{
//	float tInv = 1.0f - t;
//	fBernstein[0] = tInv * tInv * tInv * tInv;
//	fBernstein[1] = 4.0f * t * tInv * tInv * tInv;
//	fBernstein[2] = 6.0f * t * t * tInv * tInv;
//	fBernstein[3] = 4.0f * t * t * t * tInv;
//	fBernstein[4] = t * t * t * t;
//}
//
//float3 CubicBezierSum5x5(OutputPatch<HS_TERRAIN_TESSELLATION_OUTPUT, 25> patch, float uB[5], float vB[5])
//{
//	float3 f3Sum = float3(0.0f, 0.0f, 0.0f);
//	f3Sum = vB[0] * (uB[0] * patch[0].position + uB[1] * patch[1].position + uB[2] * patch[2].position + uB[3] * patch[3].position + uB[4] * patch[4].position);
//	f3Sum += vB[1] * (uB[0] * patch[5].position + uB[1] * patch[6].position + uB[2] * patch[7].position + uB[3] * patch[8].position + uB[4] * patch[9].position);
//	f3Sum += vB[2] * (uB[0] * patch[10].position + uB[1] * patch[11].position + uB[2] * patch[12].position + uB[3] * patch[13].position + uB[4] * patch[14].position);
//	f3Sum += vB[3] * (uB[0] * patch[15].position + uB[1] * patch[16].position + uB[2] * patch[17].position + uB[3] * patch[18].position + uB[4] * patch[19].position);
//	f3Sum += vB[4] * (uB[0] * patch[20].position + uB[1] * patch[21].position + uB[2] * patch[22].position + uB[3] * patch[23].position + uB[4] * patch[24].position);
//
//	return(f3Sum);
//}
//
//[domain("tri")]
//DS_TERRAIN_TESSELLATION_OUTPUT DSTerrainTessellation(const OutputPatch<HS_TERRAIN_TESSELLATION_OUTPUT, 3> input, float3 location : SV_DomainLocation, HS_TERRAIN_TESSELLATION_CONSTANT patch)
//{
//	DS_TERRAIN_TESSELLATION_OUTPUT = (DS_TERRAIN_TESSELLATION_OUTPUT)0.f;
//
//	float3 localPos = input[0].pos * location[0] + input[1].pos * location[1] + input[2].pos * location[2];
//	float2 uv = input[0].uv * location[0] + input[1].uv * location[1] + input[2].uv * location[2];
//
//	int tileCountX = g_int_1;
//	int tileCountZ = g_int_2;
//	int mapWidth = g_vec2_0.x;
//	int mapHeight = g_vec2_0.y;
//
//	float2 fullUV = float2(uv.x / (float)tileCountX, uv.y / (float)tileCountZ);
//	float height = g_tex_2.SampleLevel(g_sam_0, fullUV, 0).x;
//
//	// 높이맵 높이 적용
//	localPos.y = height;
//
//	float2 deltaUV = float2(1.f / mapWidth, 1.f / mapHeight);
//	float2 deltaPos = float2(tileCountX * deltaUV.x, tileCountZ * deltaUV.y);
//
//	float upHeight = gtxtTerrainTexture[2].SampleLevel(gssWrap, float2(fullUV.x, fullUV.y - deltaUV.y), 0).x;
//	float downHeight = gtxtTerrainTexture[2].SampleLevel(gssWrap, float2(fullUV.x, fullUV.y + deltaUV.y), 0).x;
//	float rightHeight = gtxtTerrainTexture[2].SampleLevel(gssWrap, float2(fullUV.x + deltaUV.x, fullUV.y), 0).x;
//	float leftHeight = gtxtTerrainTexture[2].SampleLevel(gssWrap, float2(fullUV.x - deltaUV.x, fullUV.y), 0).x;
//
//	float3 localTangent = float3(localPos.x + deltaPos.x, rightHeight, localPos.z) - float3(localPos.x - deltaPos.x, leftHeight, localPos.z);
//	float3 localBinormal = float3(localPos.x, upHeight, localPos.z + deltaPos.y) - float3(localPos.x, downHeight, localPos.z - deltaPos.y);
//
//	output.position = mul(float4(localPos, 1.f), g_matWVP);
//	output.viewPos = mul(float4(localPos, 1.f), g_matWV).xyz;
//
//	output.viewTangent = normalize(mul(float4(localTangent, 0.f), g_matWV)).xyz;
//	output.viewBinormal = normalize(mul(float4(localBinormal, 0.f), g_matWV)).xyz;
//	output.viewNormal = normalize(cross(output.viewBinormal, output.viewTangent));
//
//	output.uv = uv;
//
//	return output;
//
//	//DS_TERRAIN_TESSELLATION_OUTPUT output = (DS_TERRAIN_TESSELLATION_OUTPUT)0;
//
//	//float uB[5], vB[5];
//	//BernsteinCoeffcient5x5(uv.x, uB);
//	//BernsteinCoeffcient5x5(uv.y, vB);
//
//	//output.color = lerp(lerp(patch[0].color, patch[4].color, uv.x), lerp(patch[20].color, patch[24].color, uv.x), uv.y);
//	//output.uv0 = lerp(lerp(patch[0].uv0, patch[4].uv0, uv.x), lerp(patch[20].uv0, patch[24].uv0, uv.x), uv.y);
//	//output.uv1 = lerp(lerp(patch[0].uv1, patch[4].uv1, uv.x), lerp(patch[20].uv1, patch[24].uv1, uv.x), uv.y);
//
//	//float3 position = CubicBezierSum5x5(patch, uB, vB);
//	//matrix mtxWorldViewProjection = mul(mul(gmtxGameObject, gmtxView), gmtxProjection);
//	//output.position = mul(float4(position, 1.0f), mtxWorldViewProjection);
//
//	//output.tessellation = float4(patchConstant.fTessEdges[0], patchConstant.fTessEdges[1], patchConstant.fTessEdges[2], patchConstant.fTessEdges[3]);
//
//	//return(output);
//}
//
//float4 PSTerrainTessellation(DS_TERRAIN_TESSELLATION_OUTPUT input) : SV_TARGET
//{
//	float4 cColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
//
//	
//		float4 cBaseTexColor = gtxtTerrainTexture[0].Sample(gssWrap, input.uv0);
//		float4 cDetailTexColor = gtxtTerrainTexture[1].Sample(gssWrap, input.uv1);
//		float fAlpha = gtxtTerrainTexture[2].Sample(gssWrap, input.uv0);
//
//		cColor = saturate(lerp(cBaseTexColor, cDetailTexColor, fAlpha));
//	
//
//	return(cColor);
//}
//
