#ifndef TETRALIB_MATH_INCLUDED
#define TETRALIB_MATH_INCLUDED

//inverse lerp remaps value to min -> 0 and max -> 1
float invLerpByMinAndScale (float fac, float min, float scale)
{
//scale = 1 / (max - min)
//made to get rid of the division part
	return (fac - min) * scale;
}

float3 lenSqr(float3 v1)
{
	return dot(v1, v1);
}
//calculates cos of angle between 2 vectors
float cos2 (float3 v1, float3 v2)
{
	return dot(v1, v2)/sqrt(lenSqr(v1) * lenSqr(v2));
}
//calculates sin of angle between 2 vectors
float sin2 (float3 v1, float3 v2)
{
	float rlen1len2 = sqrt(1/(lenSqr(v1) * lenSqr(v2)));
	//in case vectors are parallel
	if (abs(dot(v1,v2)) * rlen1len2 > 0.999f) 
		return 0; 
	return length(cross(v1, v2)) * rlen1len2;
}

float3 softLight(float3 a, float3 b)
{
	return (1-2*b)*a*a + 2*b*a;
}
half3 softLight(half3 a, half3 b)
{
	return (1-2*b)*a*a + 2*b*a;
}
#endif 
//TETRALIB_MATH_INCLUDED