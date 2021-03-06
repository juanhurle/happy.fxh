#define UV_FXH
////////////////////////////////////////////////////////////////
//
//          UV and Texture Mapping functions
// 			
////////////////////////////////////////////////////////////////

#ifndef TWOPI
#define TWOPI 6.28318531
#endif

#ifndef PI
#define PI 3.14159265
#endif

// convert between uv and screen space (vvvv)
float2 screenToUV(float2 p)
{
	p.y *= -1;
	return p *.5 + .5;
};

float2 UVToScreen(float2 uv)
{
	uv.y = 1- uv.y;
	return uv = uv * 2 - 1;
};


float2 cubicUV(float3 pos, float3 norm)
{
	norm = float3(abs(norm.x), abs(norm.y), abs(norm.z));

	if (norm.x > norm.y && norm.x > norm.z) //project on x axis
	return float2(pos.z, -pos.y)+.5;

	else if (norm.y > norm.x && norm.y > norm.z) //project on y axis
	return float2(pos.x, -pos.z)+.5;

	else return float2(pos.x, -pos.y)+.5; // project on z axis
};

float2 sphericalUV(float3 norm)
{ 
	float2 result;
	float r;
	r = norm.x * norm.x + norm.y * norm.y + norm.z * norm.z;

	if (r > 0)
	{
		r = sqrt(r);
		float p, y;
		p = asin(norm.y/r) / TWOPI;
		y = 0;
		if (norm.z != 0) y = atan2(-norm.x, -norm.z);
		else if (norm.x > 0) y = -PI / 2;
       	 else y = PI / 2;
		y /=  TWOPI;
		result = float2(-y,-(p+.25)*2);		
	}
	else result = 0;
	return result;
};

//TODO should use pos+norms
float2 cylindricalUV(float3 pos)
{
	float2 uv;
	uv.y = -pos.y-.5;
	if (length(pos) > 0)
	{
		if (pos.z != 0)  uv.x = atan2(pos.x, -pos.z);
		else if (pos.x > 0) uv.x = -PI / 2;
        else uv.x = PI / 2;
		uv.x /=  TWOPI;
	}
	else uv.x = 0;
	return uv;
};

//UV Interface and Classes definitions

//Usage:////////////////////////////////////////////////////////////////////////////////////////////////
// iUVMode uvMode <string linkclass="UVmap,PlanarXY,PlanarXZ,PlanarZY,Cubic,Spherical,Cylindrical";>;
//
//uvMode.Map(pos,norm,uv);
////////////////////////////////////////////////////////////////////////////////////////////////////////
interface iUVMode
{
   float2 Map(float3 pos, float3 norm, float2 uv);
};

class cUVmap : iUVMode
{
   float2 Map(float3 pos, float3 norm, float2 uv) { return uv; }
}; 

class cPlanarXY : iUVMode
{
   float2 Map(float3 pos, float3 norm, float2 uv) { return float2(pos.x, -pos.y)+.5; }
}; 

class cPlanarXZ : iUVMode
{
   float2 Map(float3 pos, float3 norm, float2 uv) { return float2(pos.x, -pos.z)+.5; }
}; 

class cPlanarZY : iUVMode
{
   float2 Map(float3 pos, float3 norm, float2 uv) { return float2(pos.z, -pos.y)+.5; }
};

class cCubic  : iUVMode
{
   float2 Map(float3 pos, float3 norm, float2 uv)
	{
		return cubicUV(pos, norm);
	}
};

class cSpherical : iUVMode
{
   float2 Map(float3 pos, float3 norm, float2 uv)
	{ 
		return sphericalUV(norm);
	}
};

class cCylindrical : iUVMode
{
   float2 Map(float3 pos, float3 norm, float2 uv)
	{
		return cylindricalUV(pos);
	}
};

cUVmap UVmap;
cPlanarXY PlanarXY;
cPlanarXZ PlanarXZ;
cPlanarZY PlanarZY;
cCubic Cubic;
cSpherical Spherical;
cCylindrical Cylindrical;


// Triplaner Texture mapping
float4 triPlane(Texture2D tex, SamplerState s, float3 p, float3 n, float scale, float k)
{
	 p *= scale;
    float3 m = pow( abs( n ), k );
    float4 x = tex.Sample( s, p.yz );
    float4 y = tex.Sample( s, p.zx );
    float4 z = tex.Sample( s, p.xy );
    return (x*m.x + y*m.y + z*m.z) / (m.x + m.y + m.z);
}

// Triplaner Texture mapping w/ gradients
float4 triPlane(Texture2D tex, SamplerState s, float3 p, float3 n, float3 gx, float3 gy, float scale = 1.0, float k = 4.0)
{
    p *= scale;
    gx *= scale;
    gy *= scale;
    float3 m = pow( abs( n ), k );
    float4 x = tex.SampleGrad(s, p.yz, gx.yz, gy.yz);
    float4 y = tex.SampleGrad(s, p.zx, gx.zx, gy.zx);
    float4 z = tex.SampleGrad(s, p.xy, gx.xy, gy.xy);
    return (x*m.x + y*m.y + z*m.z) / (m.x + m.y + m.z);
}

// Pretty sure this is dodgy
float3 triPlaneNormal(Texture2D tex, SamplerState s, float3 p, float3 n, float scale,  float k)
{
	p*= scale;
	float3 Tangent1 = normalize(float3(n.x, 1, n.y));
	float3 Tangent2 = normalize(float3(n.y, 1, n.z));
	float3 Tangent3 = normalize(float3(n.z, 1, n.x));
	float3x3 TBN1, TBN2, TBN3;
	TBN1[0] = Tangent1;
	TBN1[1] = cross(Tangent1, n);
	TBN1[2] = n;
	TBN2[0] = Tangent2;
	TBN2[1] = cross(Tangent2, n);
	TBN2[2] = n;
	TBN3[0] = Tangent3;
	TBN3[1] = cross(Tangent3, n);
	TBN3[2] = n;

    float3 m = pow( abs( n ), k );
    float3 n1 = tex.Sample( s, p.yz ).rgb * 2.0 - 1.0;;
    float3 n2 = tex.Sample( s, p.zx ).rgb * 2.0 - 1.0;;
    float3 n3 = tex.Sample( s, p.xy ).rgb * 2.0 - 1.0;;
	// Transform normals into world space
	n1 = mul(n1, TBN1);
	n2 = mul(n2, TBN2);
	n3 = mul(n3, TBN1);
	
    return normalize((n1*m.x + n2*m.y + n3*m.z) / (m.x + m.y + m.z));
}


// Shader code by Inigo Quilez
//http://www.iquilezles.org/www/articles/texturerepetition/texturerepetition.htm
float4 sampleNoTile(Texture2D tex, in float2 uv, SamplerState samp, float lod = 0.0 )
{
    float2 p = floor( uv );
    float2 f = frac( uv );
	
    // voronoi contribution
    float4 va = 0.0;
    float wt = 0.0;
    for( int j=-1; j<=1; j++ )
    for( int i=-1; i<=1; i++ )
    {
        float2 g = float2( float(i), float(j) );
        //float4 o = hash4( p + g );
    	// Hash Function
    	float2 pg = p + g;
    	float4 o = frac(sin(float4( 1.0+dot(pg,float2(37.0,17.0)), 
                                              		2.0+dot(pg,float2(11.0,47.0)),
                                              		3.0+dot(pg,float2(41.0,29.0)),
                                             		4.0+dot(pg,float2(23.0,31.0))))*103.0);
        float2 r = g - f + o.xy;
        float d = dot(r,r);
        float w = exp(-5.0*d );
        float4 c = tex.SampleLevel(samp, uv + o.zw, lod);
        va += w*c;
        wt += w;
    }
    // normalization
    return va/wt;
}

float4 sampleGradNoTile(Texture2D tex, in float2 uv, SamplerState samp )
{
    float2 p = floor( uv );
    float2 f = frac( uv );
	
    // derivatives (for correct mipmapping)
    float2 myddx = ddx( uv );
    float2 myddy = ddy( uv );
    
    // voronoi contribution
    float4 va = 0.0;
    float wt = 0.0;
    for( int j=-1; j<=1; j++ )
    for( int i=-1; i<=1; i++ )
    {
        float2 g = float2( float(i), float(j) );
        //float4 o = hash4( p + g );
    	// Hash Function
    	float2 pg = p + g;
    	float4 o = frac(sin(float4( 1.0+dot(pg,float2(37.0,17.0)), 
                                              		2.0+dot(pg,float2(11.0,47.0)),
                                              		3.0+dot(pg,float2(41.0,29.0)),
                                             		4.0+dot(pg,float2(23.0,31.0))))*103.0);
        float2 r = g - f + o.xy;
        float d = dot(r,r);
        float w = exp(-5.0*d );
        float4 c = tex.SampleGrad( samp, uv + o.zw, myddx, myddy );
        va += w*c;
        wt += w;
    }
    // normalization
    return va/wt;
}

////////////////////////////////////////////////////////////////
// EOF