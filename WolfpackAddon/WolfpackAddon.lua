-- Wolfpack Addon: stacked health / power / combo point / druid mana bars for WoW: Forever and
-- Midnight, plus quest mob icons (sword = kill, bag = drops an item) on nameplates.
--
-- Forever runs the Retail (Midnight) API: UnitPower and friends return "secret" values that
-- addon code may not compare or do math on. So values only ever go into StatusBar:SetValue and
-- FontString:SetText; combo pips are StatusBars with range (i-1, i), which light up when
-- value >= i without Lua ever comparing the number.
local ADDON, ns = ...
local PT = Enum.PowerType
local isSecret = issecretvalue or function() return false end
local PIP_GAP = 2 -- ponytail: fixed spacing between combo pips; make it a setting if wanted

local TEXTURES = {
    { "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar" },
    { "Flat", "Interface\\Buttons\\WHITE8X8" },
    { "Raid", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { "Raid Resource", "Interface\\RaidFrame\\Raid-Bar-Resource-Fill" },
    { "Skills", "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
}

-- Bundled fonts are free (SIL Open Font License, see Fonts/OFL-*.txt). Static TTFs: WoW only
-- renders the default instance of variable fonts.
local FONT_DIR = "Interface\\AddOns\\" .. ADDON .. "\\Fonts\\"
local FONTS = {
    { "WoW default", STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" },
    { "Arvo (slab)", FONT_DIR .. "Arvo-Regular.ttf" },
    { "Fira Sans (sans serif)", FONT_DIR .. "FiraSans-Medium.ttf" },
    { "PT Serif (serif)", FONT_DIR .. "PT_Serif-Web-Regular.ttf" },
    { "Lato Thin (thin)", FONT_DIR .. "Lato-Thin.ttf" },
    { "Anton (bold)", FONT_DIR .. "Anton-Regular.ttf" },
}
ns.FONTS = FONTS
ns.TEXTURES = TEXTURES

-- Combat text (damage numbers) fonts, all free (SIL OFL or Apache 2.0, license files next to
-- them). Setting DAMAGE_TEXT_FONT and the CombatTextFont object covers the scrolling text the UI
-- draws; the numbers the engine floats over enemies come from the client's own font files.
local CF = FONT_DIR .. "Combat\\"
local DEFAULT_DAMAGE_FONT = DAMAGE_TEXT_FONT
local COMBAT_FONTS = {
    { "WoW default", "" },
    { "Anton", FONT_DIR .. "Anton-Regular.ttf" },
    { "Fira Sans", FONT_DIR .. "FiraSans-Medium.ttf" },
    { "Bebas Neue", CF .. "BebasNeue-Regular.ttf" },
    { "Bangers", CF .. "Bangers-Regular.ttf" },
    { "Luckiest Guy", CF .. "LuckiestGuy-Regular.ttf" },
    { "Permanent Marker", CF .. "PermanentMarker-Regular.ttf" },
    { "Russo One", CF .. "RussoOne-Regular.ttf" },
    { "Black Ops One", CF .. "BlackOpsOne-Regular.ttf" },
    { "Press Start 2P", CF .. "PressStart2P-Regular.ttf" },
    { "Bungee", CF .. "Bungee-Regular.ttf" },
    { "Righteous", CF .. "Righteous-Regular.ttf" },
    { "Titan One", CF .. "TitanOne-Regular.ttf" },
    { "Lilita One", CF .. "LilitaOne-Regular.ttf" },
    { "Alfa Slab One", CF .. "AlfaSlabOne-Regular.ttf" },
    { "Archivo Black", CF .. "ArchivoBlack-Regular.ttf" },
    { "Passion One", CF .. "PassionOne-Bold.ttf" },
    { "Cinzel Decorative", CF .. "CinzelDecorative-Bold.ttf" },
    { "MedievalSharp", CF .. "MedievalSharp.ttf" },
    { "Pirata One", CF .. "PirataOne-Regular.ttf" },
    { "Creepster", CF .. "Creepster-Regular.ttf" },
}
ns.COMBAT_FONTS = COMBAT_FONTS

-- The layout new profiles start from: an export string, read through the same checks as one you
-- paste in. `decodeExport` is defined with the import code; until then DEFAULTS are used.
local DEFAULT_PROFILE = "WPA1:7Z1rjBvXdYBntLKwFVyndgSUK7SGUsBFgNYGlMjuOqhDU+TwsavVSrsrSDYEJ7Pk7C6x5AwzM9RqlRbYNCpQoG7yI2lr+0cCW7Kl2qnyLCqngOHYDRKjD7vP2LDj9IUUgfPDCDg/vItCvffOk/PizHDI4ZBHP1ZcieTce8655957znfufa7UEoW1eoN7gRHkDU58gdkQLnDi00yzXhUF5cRGvcaVxO3WhsBLyhzbloUlrsXWRaUscY3GXJvfVOaqQnOVlYsCL58rVXiZE9fYKnc+V6st8tL5s0JjrcVWN9GvAn8ev0k6nycfOH+KE5ssz/HyAitucuK9S9x6u8GK98ny2gn8JPS2VoOTOaUisvVaGbfrmYK0IWwpTFVoCOJlmqb3sq89if88VWrW+XqTbf1FUfpMmxW5TkEW2e1OcVUQa5zYyW1TuYsU6U6B3T5ZX9+QOyfwO4436pcusWKtU6rza8JxVuwURbZWb0vT+TVJvKY+L3cx85sFJKWG5ck0+sqCVL/E/Up+lRWZlrDFiXOr7Lq0yC+2OF4VVq5a5VqyUpQ2WNTVb5SEttyo85yiPYMqrIvCFiPi5hS2WJH/Jcv3V/A/5NVfP/gEZfSUzq+zrf3MWoOVNpTc9oP0FOpZeQ1Jdhm15vYCfrWkCrq4VHn09MqnPnXfykqx2BCqm1xNKVWFNi/n5GJVEHlOVDtIOpI5UhJVFdwg7Trebi22Guw2Jy4IbYnD8lcqG6itDdxehyo+OEYxRNiPz8msuM7JVVaSS/gHlo+0VefXVSkVNzi2IW9UWpysvmKwBQmVmtiu15CY2KIsyFxTKrKrkiCuFtfI8+Y5nmtuqx9QJcC2RVa6rjajqDb0iq6ve3TtZDIlCdkfevi+YosTl4St6SLSJLLSPNtoMDzb5KQdhny38eED2FqQYGVsMuoXr5AeKYvYgE6Rf0EqbHK68VeqAn9NtTFGkrcbHMPKSD9qC+5Wvxebidb1uTVRaOY5PFaUAvpn6Wtal2/O6CbSqdTqIleV6wKv2secaskLQo0jBqfKfS/73x8nf5wvaEZqCLJ0md43tb+0uq5aEkVRH8xS2ndhe9lXabG144IsC01qDn+AvE+6fBkNrX/Rv/FFzfIuo8/uZf99jfwxDfKy8RL9P02bjSJv//nf4z//QJdk7qLcFrlzh00ncbyNHoy9RLmywsyem9XH3rzaQKPNdIV0F3e+WG1LqLFF1OwVoUUV8Ld2NFvcqtfkjcw7qiKMIXHQc0hscFiyB8vr+LFIHR2kPKEl/cEzAaSbbwkSZb7xH2+efu8P777pfEHemKlVcDvzxuDWbPuvg6hb67HxKE2glhc/VTVCe6uZckjUUMc9pjpUK0djhRj3+TOVe5dlVm5LyC3qHstiLv46UYhOOgPQiXf/bTr50cGHWld+dNDy4p+wRk7/3F0nFrd189dDj8OfqSPAMmq0F3atlPDEsIycybzqkfOepvY/2six6JEu15GrWcbTWINbkx2y8W6FTTb/euk/SzcO/f5e9iXdXl/qsleHvRTwg5Ugg7iCnZzeq9f0BhnK0hukWdR+04wKWDK6E9asSLcpix0R0zl3f6ClRk68IFgXFpUNVmzm7YZkCEv3aKadavaYOWwapHUIdFuQOr/dPGwYzzz5B9WlXi0s5E7mkCzR6GdOMkulR9BnKJopLubPLKMpfpZCMyhdWMqVmMs0FnhVkGR9fkV+9Mc/fhfrge6yp91sntrn5c4dLqRbqbtZ5vs/oAP5ZUMeH9I9tH1YOJyBqrAZ+rdVPSKFVnCHDGEZ84i2AulDqbqNINtwUZdtjFC7n3z//V/Q3eMBifeNN974ya1bt/aybz355MtYzu5+W12MRPLbb+lDQXdXY+Sv7/Dx185+23zR3xJf9FnDPRsfcdeBdSV48zc8NVEWOUloi1VO8fKSaLxZVtUe/vFFvfXfIf/ye3qb0LcvEREXWmhjMI9+LSOvvIIl6dCdPmg0l7bKSeithmtDcl5AHz/eNa9ocr3LlKuhizt9VnMF9EXnqEBDGr3zLNH1YyeNp5tNNltEzNG0HaaKFraSfRbUrEYdy1g2ZdL8KV+RW2wTu3X0qUcO9OXcbWNVM5HDUQarMW8ZM6re6m73O39mycP9FtXlRKfLGnY/ubPzOVr9GXou1UcFWVa/o05eumk5bNy7AzZL/96ddx6hqH272V/+ky8Yv+lWbncZWE/qitvDH+hu/ynDueAeKKYjQdauO+mPmsatGU63As0dYiR/a8zqP9U3LG4rst3sx848YlVhl772sm+++SaaFm7tZtf/92fGb6E2M4FdcNc2Bs2cIX3wtI8P9paFzRqM5aDhi1/y28eo+/qbh1Ff+XWuFlw9u9lDX/5T7cfdX/mqz1RoHVPdYynbev8X5Aduh9dC2HjxXo+FsPHi31754vmPKq9qHQ6iacM6NZVnjuh6dShcW+0QdeeFtbWORdsHvBRcaLJ1XjFHzh0us8JBm2b0yIsZUlBCjJ0/ymQepqipvey77/4ETwe7D7388iu2cXP3mXNWNXXvTMh2oRPIxVlcptv2fy/75UOHjuA2ZCuv/d1e9tUvfemreAhq68ptLxkbgjXGWB9TiyHmQ+7+S7W/zxvrSXr3dynk4rtsbTf7q3/+BPoPLEliW0VzTZqdwSb6wyee8F56mvGxSN7QmA+0iWO0Vp99ur4DPq7P2XGbB9AWdnvZH+hhAt/lpxqtjKADt4jaGOngdk8duHXcpgNjj2DMP1e7l9u2UI0Wl+b4tnIKx2RJGD+vejyFEYX1Njfy0Xbk1de5bxqtNL/U0iz9e7SPzG2xSPPFuijJSrkhbOV1+Rrye8va7Ap+XB63QOl/l527OEPX8uiht9k65SJeLKjvlZBIcfP/ytnFzIylj6dYsSmIi3xje6EuSciWle5eH9MfYHsufsiLuFWPDVsUlp5qlrFA+lDUNYjFNFUh/0a6e4Qhr5XiRhs/71v+Si+wzaZgE8IRXQiR++pipciUcUszP7Sbqdm/PFqDI7uf/bbeHGa1vbYmfc2nBziSNUvRakPR196mRhZyFx+kf6sgbdZbO/p3zQum0j13FHom5y7mM21Okp9V3VJhE+26rxo5KNJXvOQ4TNG3vk/ef8hI/BQagiB7vPd19b0VnAhCTkXmnsttfwSncdRUVlfGyp6n0pdYlkwWWQ53568sYWWXVFaE9I99Zu8zA0QNPwMUbgKLlAzSA1l8yFnsNkgGDTy4GKdORiYZZFeMse8caD6IGpV8UDDDCZcaotxSQx2v1BCvp4ZcDClq2mc6maxPx9wXfuTpZ3x3aiHyPdZxHiTXc7B3rkftuqaAx1X3GyjT4zbYHVmc/X47iveC7ii0cE6PHcWkJHbC+l6/oKKz32OV2KGsSZ2OV1JHW3RoSZ1OkKTOtFv4zsdkbEmdYHZi5nceDZXf0UzIxdw1A1LNyczx7A+b45ny9NLu+ZtIi2JjcjFmQL1FwZxpJNcZOFujpTsiZlcyj3clVzpuyZVAETGHbLwiY8ag+Y6fDx1KviZpdzq47cXI5Wj8sijeKqG98zV3fOGL2g8cCR9CziaYDdjTN5R/9qbjyN74rj3jSd6ECjNrBkT5DRyXdE3o1bwjc+Mcjj2yNIYAu5I0LlJ083HeaxOrDLzWhdrgoSY22xLVh3kvyyHZMiQVeM/u8edacEh5H4kIF2rCFj+Ico8Cjr4Wl0mRRFkrSJGul86yolgXxBvpKE1xKUpRl3kjXZpSRk9CzePXr8zjooSF7RPcBa6B6zxq3DyP9I3ESbIJUsQyFpIzsybRDMDXnnTokUozEw2euTpbGctfmlYbrZAlYL2KusDS5+ww0X8sl9ty27MfhKo0eY6YTObPgpSakPzCC5Bf6Cu/YOzL7DS6YctQbDLs2VTXiaNCwIgSp6bY5NcMxZhNHlwkP3yGwle1Fh11bymcRjWUlEGvugRbbNQ/0KJh8AHTB6rlObd5gRM77okFb6dtTxbcd+Pr9vKQu57/Zu/yEDxfBIlv2etHyFb+1Bv/bADuZp2IKl6DJbKnDNQN4WDKQfAGUVNy73KQFGcSLLqM6F/jj+h3u2Tnnj/QcLM4bq8R5fBCQ0f/vSHltID/PaO73uFpEnZ2ALZh5lyA/z2XlbhmLvS6EuD/0YH/3aKd3cGfbvLfPy8O8H864H8IPg/F0QHqn7wO0o36JxCR7A/17wyA+Q4E8c/+cbnWRlM78tjX8zK7SkDq8mqjzWFav4PEJwgiPUcevcHyVU45ScLYAs+dxqy21Cm06tVNqtRkxU3MeJeFFseTz/oUB1iF0qs2wMDiNcDeytyj9r8dp+RsjL9uPBaBqaKdsos2xdA/Qe6lq6beyk3UA/xKKeuqVgqX0M+HR7hAwKwM0PF/7wIBszKg673JFghAAH8wAXw+fLAYCgQGHMCPWScQwJ/kAD4fPYA/nUAAvy/aP3wE33I0jWWsEUepk6aRAvfuqw5bUH4s6f7xi8k70SSvQRIwJj+JOLclXm7C27FHPRyyAZw7RCQk7oXHyEXdJxbnDhWP180AcG7AuVMXUY/iwwDnTlwFCeLcTAEPDECs04xYa9Cvy0FFgFgDYp3uCC0g1snPcIBYQ4TWJ0LbJ/NpGFPAIK15Pkh8iLU3J9odoY1wCr/HYTDmiS+2o2Csp8TEgGiTI/6deLb7ES4BTuuPg6ciaydya8+4nNY/imHfWCofUoFiT/Ap7ABiA4gNIDaA2ABiwynsiWPBgGYnr4N0o9kJRDLH/RT2NBPcqrjCiZgQ2Pj0xV60tjdOPPs2ENxAcAPBnYb8ABDcya9bgOCG/MDA8gN89PxAfAR30PxAKII7psxAvPR31LPdewFf9pg/0N+pSAMA/d076A/0N9Dfox/qB/ob6G+gv8c6aA/0dypVkCD9rZ25/UI68G87RWxY6Ejj35GQ7gSuo9WR7hukXcfbrWhAtyWqok986polIOndHVn1ALr3M2xbZKXr2pZSbegVXV/36NrJZIwAcbHFiUvC1nQRaRJZaZ5tNBgcEJZ2GPLdxocPYGtBgpVD8eLXVBsLgovP4SKAPIfHihLh9k9icDHFhfcNPy4cgNSJdN+n4smtASye9J1zcepkGMHgQPd9do3DwHHcvi77pEflss+gUZOeseL9bjd8Kl43fL6j37IUMXce9RZQK588zGtA9fk1Cnbe6zJQjQwPdSHoh3pfCNp1V2AAnLx/IMJ5bWj6cfKU+es7fPx1//Hrbh2M2B2hhRbaGFjvCVU8cyyaS1PvCVUsYWDPe0Lvcgku3emzmrPdE+o3pI3LQR8LdTkoU0ULW8k+C3ZV6pkXg075itzlYtADfTl3KDsYXtmBb9John6q635SxS3cB2UHftsYNHPGeE/zyOUixrzswP/6UMWt8iC3fQDKDqDsYGLKDuJ0fVB2kLwO0l12kEC0fdzLDnyqAzIzIcoDjukPsD0XP+RF3KrHhi0KS081y7CVGpAKBGsZg1bZkOYqgtGtDNAZf6NAwKcywP7e10ehMiBc+gcqAwJMY1Gv1YbKgMEHF+PUycgkgzxRu4Hmg6hRyQcNpozAJTXU8UoN8XpqyMWQoqZ9ppPJ+sR1HHwk6NkihJ65nnAFAv6LEWcWZywLBFLme/2Cis5+j1Vih7ImdZzVDca2R2UA1aROJ0hSZ9otfOdjMrakTjA7MfM7j4bK72gm5GLuXXSjmePZHzbHM+XppaFeJFB2xawgUetK3JIrUC8y0CjZIJayI5ejmdh6Ef/sTcelZMRn7Qn1IlAvMpLZlqg+DOpFEldBgvUipbNqVD8d9wU8rfZ6Z6TLQ4zbAXa0QpFnzGzUjt4BOG0fTtuH0/bHO2Y+PqftX9cluWONau+YcdgdrVW6g9b/1v4yd9I7VsHvmE/cCXazZrwAfYzHr6uKNmALN1sYGDDvvIlz0MD8s4Y9+OvdS9nA8g6S5SWILhwhDkeIA8sLR4gDywssLxwhnr7w0jgfIe4SEBl3etY4tHtH52hvOIBmS1d79IfwqGZ/CDobiw/NzGgHcGiiJjyug3pWMd4Uw6/qEdo7owjBXukGW13QV7d3wFHY4xi8g6Owk59/038U9sgE7+LiIGM6GFkdcjqDY6cgAwXs3OchWzAuAe4xrvjcJLJacLbvCLFacLbvhLFacLYvsFqTEU2Ds31TqYIEWS1mCQfP0kFqGUKxHOqrLr1Gjd3quLJbV+bxoa4L2ye4C1wDo1g1bp5HOkDiJAEpaZDHADsjvGFPJiBHG9iOAe6fNSMewYM4A9Zs4sNVwJolP8OlnzVL1c1tfmGLsAXgCV/qpt/n1TFOeNVNqNcGIWA5tnNf59yVde2M3AuzvaGJriDjbvbT//Ffu9lPfPdvqGESgrvZz+79H72bnfr85YmnBCfzejaHH3DbgYcYXeqgdJxlYBk1qlXFeVzqqx/+sIr1EPZF+w3wSkeAGPBKwCvV0G5wgs8Pr9zN3v/8cwBYAmAJgOUkhoTHCbC03KZCo0n7u4cP40HVJfi97OvPX/s0RdHBxD9CE05mZsSIyviDkB1n4KCfIGQEvjMaJUigTG84Y4auER5Ti0V7soIWuLRjsJvX8zK7Shi88mqjzeEzTjtIWoIg0nOkBRssX+WUkyR4LfDcaYIZdspCi+PJm0tNVtwkYGCrXt2kfI5Utcql14mqhqQc8p992zOpFwG9xIji8I9KfUDr3e3x0qIzNBOQF32Q/oYGjF4tXEJafbjcRB3A6lDKuqYVU8ejCJUO4WRVl9wAgKZpidwDaJr8WjD9oClE7kcsct8T7ekzcj8dMXIPeHCyeDAE5gME5nsOHo/A/HTAwDyw1cBWj8TCA9hqYKuBrQa2eowC6ePLVu8+9PDLr/iOgJjEHiWWnnk8zvTFwHnqYpnEJAGoHsZhmIkC1R43vZ3LOpTGNC6cqZwv4UGxjDbHXO38Alers5r6Tq0ss7x0khVRe8hV5QHuhYOjPgG/Bvx6QoO4gF9DEDdYEFczlBCsaN+zV8Dor2bY/cHaPUK+cJwrgNqjEA/2r33oe8T1ZrkdlhYn1h0segxoN6DdI0PaAdoNaDeg3YB2pz0iPU5od1qP+xiLs3PHLDo6Qly4KxKuwuLjxYWbgyC0BKdi2gf1wsgxug4U+eRR5HBccYoTEECRJ7/kAYocEhCDS0DwyScggDkH5ny8cgwxD6reWHrQHAMQ6kCoj8SiBgh1INSBUAdCfYzyAeNLqKcmHZCy07+Lp8Q6J8lAq489re51/PegEjKDOSwcaHUIFgOtnqpgMdDqECwOFiwOeFj4sCLEcR8tDrQ60OopiCQPr1QkiUPIg0WSgVYHWh1o9ShRZj9avdshAqsOrDqw6hMTmwZWPaU6mABWPcnYaARW3YKLK5HJ48g7sxm6RrB3W59clEEw93Tz7PGYQQQkPsix6LHz7BGrIHqCYgFp9tlvA8wOMPs45ycAZk9+TQQwO+QnBnoketL5CYDZAWYf2xTE0Ll2OG4dYHaA2UctzQAwO8DsALOPdcIAYPZUqiBBmL2wwK5zgLKPPcrucbRQ8Dtk4Sh1gNMBTofgL8DpEPwNGvwNf5R69Ksx4XB0wM0nJdbrX+sR/IZMOO4cAHIAyAEgFwAgB4AcAPLxiwcDQJ5SHUwAQB5vRBKQ8NFEwjFvHfqA8x4TeC/Gm8DgAHkD5A2Qd1ri/AB5J79uAcgb4vzDOrE8pjg/YNuAbY9XKL/nMIFTxbXnAYgNIDaA2AKA2ABiA4g9Dj4MQOzEVZAgiF2qNlhJ4qTrxfKZkyvMUrFMgpWls7mlpcriUuksK4p1gfx+YjE/j3/Hm8Ticjm3kDtZXCbgcGEhV2II0s0Uls5UCkwBjzZmabF0hmGWcCC/eGqpwiyvaGeYl5EvRLKubj5bardqrMzVqNIFTpSQHewroqa1W9Lnrh6v106vH/2dBz/+wMdm7z929N6jDxw7ehSJB33sGo5N4sVrS6jzcjHP4JYvYrEvtuXFNZX1VhipyjY4mmEbrQ2WPoH/u8Jr/1fA4bwSacORoyTEtsNgnyld1Tdj2NldEoTmtIZz79MvkDxh5CpYsab8Pw=="
-- Ready-made profiles, listed in the profile dropdown even before they exist.
local PRESETS = { { "Alpha", DEFAULT_PROFILE } }
local decodeExport
-- Declared up here because the code below closes over `db`: further down it would bind to a
-- global of the same name instead, which is always nil.
local store, db, class, charKey, classProfile

-- Called on ADDON_LOADED, before the world loads. Only known paths are accepted.
-- The font of the active profile, or — before a profile is loaded, which is when this matters
-- most — the one baked into the addon.
local function applyCombatFont()
    local pick = db and db.other and db.other.combatFont
    if pick == nil then -- no profile loaded yet: this is the load-time case that matters
        local data = decodeExport and decodeExport(DEFAULT_PROFILE)
        pick = data and data.combatFont
    end
    for _, f in ipairs(COMBAT_FONTS) do
        if pick and pick ~= "" and f[2] == pick then
            DAMAGE_TEXT_FONT = pick -- read by the engine at startup: the floating numbers
            -- The scrolling combat text is drawn from a font object, so that one can change now.
            if CombatTextFont and CombatTextFont.GetFont then
                local _, size, flags = CombatTextFont:GetFont()
                pcall(CombatTextFont.SetFont, CombatTextFont, pick, size or 25, flags)
            end
        end
    end
end

-- x/y = offset from the bar's slot in the stack.
local function barDefaults(show, width, height, r, g, b, text)
    return {
        show = show, x = 0, y = 0, width = width, height = height, texture = TEXTURES[1][2],
        color = { r, g, b, 1 }, bgColor = { 0, 0, 0, 0.5 },
        gradient = false, direction = "right", -- "right", "left", "down", "up"
        stops = { -- gradient points: percent across the bar, and a color
            { pos = 0, color = { r, g, b, 1 } },
            { pos = 100, color = { r * 0.4, g * 0.4, b * 0.4, 1 } },
        },
        text = text, padTop = 0, padBottom = 0, -- extra space above / below this bar
        font = FONTS[1][2], fontSize = 10, outline = false, textColor = { 1, 1, 1, 1 },
        colorMode = "custom", -- "custom", "class" or "power" (power bar only)
        borderSize = 0, borderColor = { 0, 0, 0, 1 }, borderMode = "bar", radius = 0, -- border: or "class", "custom"
    }
end

-- One layout per place the bars can show. x/y = the group's top-center: from the screen center
-- (regular) or from the bottom of the target's nameplate (nameplate).
-- One bar per weapon; the Swing Timer bar shows the ones ticked here.
local SWING_TYPES = { { "main", "Main hand", 0 }, { "off", "Off hand", 1 }, { "ranged", "Ranged", 2 } }

-- Incoming heals come from a calculator object: it takes the secret numbers and hands the bar a
-- value it can draw, so nothing is read here either. The cost of the spell being cast is read
-- once per cast and only ever passed on.
local healCalc = CreateUnitHealPredictionCalculator and CreateUnitHealPredictionCalculator()
local castCost = { value = nil, have = false }

-- Only the cost of the power the bar is showing counts, and the number itself may be secret:
-- a plain flag says whether one was found.
function castCost:track(event, spellID)
    self.have = false
    if event ~= "UNIT_SPELLCAST_START" and event ~= "UNIT_SPELLCAST_CHANNEL_START" then return end
    local ptype = UnitPowerType("player")
    pcall(function()
        for _, cost in ipairs(C_Spell.GetSpellPowerCost(spellID) or {}) do
            if cost.type == ptype then self.value, self.have = cost.cost, true end
        end
    end)
end

-- The Shield bar fills to the size the shield had when it landed. That size can't be computed
-- from a secret, and the aura payload that would announce a new shield is secret through and
-- through -- even its isFullUpdate flag. What is readable is the clock and our own casts, so an
-- absorb change right after a cast of ours counts as a shield landing, and anything later counts
-- as damage eating it. A shield cast by someone else leaves the bar on its previous scale.
local absorb = { max = nil, have = false, castAt = 0 }
local ABSORB_CAST_WINDOW = 0.4

-- The Totems bar is one segment per element. Order and colors are per profile; these are the
-- game's slot numbers, which never move.
local TOTEM_SLOTS = { "Fire", "Earth", "Water", "Air" }

-- Everything about a totem's timer is secret, IsZero included: the duration object may only be
-- handed to the bar, never asked about. So the addon can't tell an empty slot from a full one,
-- which is why this bar stays in the stack instead of collapsing like the cast bar. An empty
-- slot's duration is zero, so its segment simply draws empty.
local function totemDuration(slot)
    local ok, d = pcall(GetTotemDuration, slot)
    if ok then return d end
end

local function layoutDefaults(show, x, y, gap, width, h1, h2, h3, h4, h5, h6, h7, h8, h9, h10)
    local l = {
        x = x, y = y, gap = gap, grow = "down", -- "up": the group's bottom edge stays put instead
        order = { "health", "enemyhealth", "tothealth", "power", "combo", "druidmana", "castbar", "targetcast", "pethealth",
            "swing", "totems", "absorb", "flight" },
        bars = {
            health = barDefaults(show, width, h1, 0.2, 0.8, 0.2, show),
            power = barDefaults(show, width, h2, 1, 0.85, 0.1, show),
            combo = barDefaults(show, width, h3, 1, 0.3, 0.1, false),
            druidmana = barDefaults(show, width, h4, 0.2, 0.45, 1, false),
            castbar = barDefaults(show, width, h5, 1, 0.7, 0, true), -- text = spell name
            pethealth = barDefaults(show, width, h6, 0.3, 0.7, 0.3, show),
            swing = barDefaults(show, width, h7, 0.8, 0.8, 0.85, show), -- text = seconds left
            totems = barDefaults(show, width, h8, 0.6, 0.6, 0.6, false), -- colored per element instead
            absorb = barDefaults(false, width, h9, 0.9, 0.9, 0.7, true), -- text = points left
            flight = barDefaults(false, width, h10 or h5, 0.4, 0.7, 1, true), -- text = time left
            -- the color is picked from what is being cast, so its own is only a fallback
            targetcast = barDefaults(false, width, h5, 0.8, 0.3, 0.3, true),
            -- your target's health; its resource (mana, rage...) always sits right under it
            enemyhealth = barDefaults(false, width, h1, 0.8, 0.25, 0.2, show),
            -- your target's target; it can hang below or right of enemy health instead of stacking
            tothealth = barDefaults(false, width, math.max(4, math.floor(h1 * 0.4)), 0.8, 0.25, 0.2, false),
        },
    }
    -- beside: right of your health bar, the two sharing its width and its height. The resource
    -- sits inside the health bar: width in percent of it, x/y from its bottom center.
    -- Health, power and enemy health: three numbers, each with its own switch, spot, size and
    -- color (the bar's font and outline). textsSet: useProfile has moved an older profile's text
    -- size and color onto "current" (once).
    for _, key in ipairs({ "health", "power", "enemyhealth" }) do
        local function num(show, anchor, x)
            return { show = show, anchor = anchor, x = x, y = 0, size = 10, color = { 1, 1, 1, 1 } }
        end
        l.bars[key].texts = { percent = num(false, "RIGHT", -4), current = num(true, "CENTER", 0),
            currentmax = num(false, "LEFT", 4) }
        l.bars[key].textsSet = false
    end
    local eh = l.bars.enemyhealth
    eh.beside, eh.resource = false, true
    eh.resHeight, eh.resWidth, eh.resX, eh.resY = math.max(2, math.floor(h1 / 4)), 90, 0, 3
    -- its own text switch and border; the rest of its look (texture, font...) is enemy health's
    eh.resHideText, eh.resBorderSize, eh.resBorderMode, eh.resBorderColor, eh.resRadius =
        false, 0, "bar", { 0, 0, 0, 1 }, 0
    -- level and name, inset in the bar; the level always wears the game's difficulty color
    eh.tagLevel, eh.tagName, eh.tagFont, eh.tagSize, eh.tagOutline = true, false, FONTS[1][2], 10, true
    eh.tagAnchor, eh.tagX, eh.tagY, eh.tagNameColor = "LEFT", 4, 0, { 1, 1, 1, 1 } -- tag*: the level's spot
    eh.nameAnchor, eh.nameX, eh.nameY = "LEFT", 28, 0
    eh.tagAttach = "free" -- the level: "free" on the bar, or "left"/"right"/"top"/"bottom" of the name
    -- a box behind each: color (with opacity), padding around the text, corner radius
    eh.tagBg = { show = false, color = { 0, 0, 0, 0.6 }, pad = 2, radius = 0 }
    eh.nameBg = { show = false, color = { 0, 0, 0, 0.6 }, pad = 2, radius = 0 }
    -- buffs and debuffs, on your health and on enemy health: each group sits in a spot of the bar
    -- or of the other group (anchorTo "bar" / "other", auraGroupGap apart), with its own nudge,
    -- icon size, corner radius and grid
    for _, key in ipairs({ "health", "enemyhealth" }) do
        local b = l.bars[key]
        b.buffs = { show = true, anchorTo = "bar", spot = "topleft", grow = "right", wrap = "auto", x = 0, y = 2, size = 20,
            radius = 0, cols = 8, rows = 1, max = 8, hideTimer = false, zoom = 8, lineEdge = "bottom" }
        b.debuffs = { show = true, anchorTo = "other", spot = "topleft", grow = "right", wrap = "auto", x = 0, y = 0, size = 24,
            radius = 0, cols = 8, rows = 2, max = 16, hideTimer = false, zoom = 8, lineEdge = "top" }
        b.auraGap, b.auraGroupGap, b.auraLineGap = 2, 4, 1
    end
    -- small icons on the bar: PvP flag (in one of a few looks) and drinking; centered on a
    -- point of the bar, nudged by x/y
    -- anchorTo: "bar", or "name" / "level" (then it sits outside that box, on the side of point).
    -- style "text": text instead of an icon, in the name's font and size, its own color.
    eh.pvpIcon = { show = true, style = "faction", anchorTo = "bar", point = "TOPLEFT", x = 0, y = 0, size = 20,
        text = "PvP", textColor = { 1, 0.25, 0.25, 1 } }
    -- drinking: the name reads "Drinking!" instead, flashing, in this color
    eh.drinking = { show = true, color = { 0.35, 0.75, 1, 1 } }
    -- target of target: anchor "stack" (like any bar), "below" enemy health (the two then share
    -- enemy health's height: your health's while beside it) or "right" of it (its height, own
    -- width). It has enemy health's level and name, the name shown.
    -- your pet: anchor "stack", "below" your health (your health's width; enemy health beside you
    -- grows to match the two), or "left" / "right" of it (its height, own width)
    l.bars.pethealth.anchor = "stack"
    local tt = l.bars.tothealth
    tt.anchor, tt.width, tt.colorMode = "right", 90, "class"
    local function copy(v)
        if type(v) ~= "table" then return v end
        local t = {}
        for k, x in pairs(v) do t[k] = copy(x) end
        return t
    end
    for _, k in ipairs({ "tagLevel", "tagName", "tagFont", "tagSize", "tagOutline", "tagAnchor", "tagX", "tagY",
        "tagNameColor", "nameAnchor", "nameX", "nameY", "tagAttach", "tagBg", "nameBg", "drinking" }) do
        tt[k] = copy(eh[k])
    end
    tt.tagLevel, tt.tagName, tt.nameX = false, true, 4
    -- your health: a status icon (the combat icon in a fight, else rested while resting) and
    -- your own PvP flag
    -- resting: the Zzz icon, or your own text (bar's font and size, its own color), whose letters
    -- can fade in and out one after another
    l.bars.health.statusIcon = { show = true, style = "atlas", rested = true, point = "LEFT", x = -12, y = 0,
        size = 20, restStyle = "icon", restText = "Zzz", restColor = { 0.6, 0.8, 1, 1 }, restWave = true }
    l.bars.health.pvpIcon = { show = true, style = "faction", anchorTo = "bar", point = "TOPLEFT", x = 0, y = 0,
        size = 20, text = "PvP", textColor = { 1, 0.25, 0.25, 1 } } -- text: in the bar's font and size
    l.bars.power.colorMode = "power"
    l.bars.health.colorMode, l.bars.enemyhealth.colorMode, l.bars.castbar.colorMode = "health", "reaction", "cast"
    l.bars.druidmana.colorMode = "power"
    l.bars.castbar.icon, l.bars.castbar.iconSide = true, "left"
    l.bars.targetcast.icon, l.bars.targetcast.iconSide = true, "left"
    -- what your target is casting. "Auto color": one color each for a cast you cannot stop, a
    -- heal, and everything else. autoSet: useProfile has moved an older profile, which always
    -- colored by kind, onto auto (once, so picking another mode sticks)
    l.bars.targetcast.colorMode, l.bars.targetcast.autoSet = "auto", false
    l.bars.swing.main, l.bars.swing.off, l.bars.swing.ranged = true, false, false
    l.bars.health.heal, l.bars.health.healColor = false, { 0.4, 1, 0.5, 0.45 } -- incoming heals
    l.bars.power.cost, l.bars.power.costColor = false, { 1, 1, 1, 0.35 } -- what the cast will take
    l.bars.totems.slots = { 1, 2, 3, 4 } -- left to right: which totem slot each segment shows
    l.bars.totems.slotColors = { { 1, 0.3, 0.1, 1 }, { 0.5, 0.35, 0.2, 1 }, -- by slot, so a color
        { 0.2, 0.5, 1, 1 }, { 0.6, 0.5, 0.9, 1 } }                          -- sticks to its element
    return l
end

-- Holding a secret value is fine; testing one throws. This client can say which is which, so
-- ask before comparing anything that came out of an aura.
local function readable(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return false end
    return true
end

-- Quest mob icons on nameplates: a row (kill, then loot) whose top-right sits at the nameplate's
-- top-right corner plus x/y. Icons are file IDs.
local DEFAULTS = {
    locked = true,
    regular = layoutDefaults(true, 0, -120, 2, 220, 18, 14, 12, 6, 14, 10, 10, 10, 10),
    nameplate = layoutDefaults(false, 0, -2, 1, 110, 8, 6, 6, 4, 8, 5, 5, 5, 5),
    quest = {
        x = 0, y = 0, spacing = 2,
        kill = { show = true, icon = 131013, size = 20, count = false },
        loot = { show = true, icon = 131023, size = 20, count = false },
    },
    other = {
        hideGryphons = false, autoAccept = false, autoComplete = false, sellJunk = false,
        autoRepair = false,
        hover = {},         -- [key from HOVER_FRAMES] = true: that Blizzard element shows only on mouseover
        bagsOnOpen = false, -- bag bar only while bags are open, attached to them
        raidHover = { show = true, color = { 1, 1, 1, 0.2 } }, -- overlay on hovered party/raid frames
        combatFont = "",    -- damage-number font; "" = WoW's own, picked on purpose
        minimap = { square = false, border = false, radius = 0, tray = false, trayBlizzard = false,
            infoBar = false, hideDayNight = false, x = 0, y = 0 },
        -- five-second-rule spinner: centered on a bar (or the group, if that bar is hidden) + x/y
        fsr = { show = false, bar = "power", size = 28, x = 0, y = 0, color = { 0.3, 0.6, 1, 0.7 },
            fill = true },
    },
}

-- Rogue and shaman: what is on each weapon, and when it is nearly gone.
-- (a local would put this file over Lua's limit of 200 of them, so it hangs off ns)
function ns.weaponDefaults(y)
    return {
        show = true, locked = true, x = 0, y = y, size = 32, gap = 4, grow = "right", radius = 0,
        warn = 9, flash = true, countAt = "corner",
        font = FONTS[1][2], fontSize = 12, outline = true,
        color = { 1, 1, 1, 1 }, warnColor = { 1, 0.75, 0.2, 1 },
    }
end
DEFAULTS.rogue = ns.weaponDefaults(-260)
DEFAULTS.shaman = ns.weaponDefaults(-260)

-- Warlock: the soul shards in your bags.

DEFAULTS.warlock = {
    show = true, locked = true, x = 0, y = -220, size = 32, radius = 0,
    armor = true, armorSize = 32, armorFontSize = 12, armorOnlyMissing = true,
    flash = true, gap = 4, grow = "right",
    countAt = "corner", showCount = true, low = 3,
    font = FONTS[1][2], fontSize = 12, outline = true,
    color = { 1, 1, 1, 1 }, lowColor = { 1, 0.4, 0.4, 1 },
}

-- Hunter: ammunition left, and how the pet feels.
DEFAULTS.hunter = {
    show = true, locked = true, x = 0, y = -180, size = 32, gap = 4, grow = "right", radius = 0,
    ammo = true, pet = true, countAt = "corner", showCount = true, low = 200,
    font = FONTS[1][2], fontSize = 12, outline = true,
    color = { 1, 1, 1, 1 }, lowColor = { 1, 0.4, 0.4, 1 },
}

-- Mage: the conjured food and water in your bags, best rank only.
DEFAULTS.mage = {
    show = true, locked = true, x = 0, y = -140, size = 32, gap = 4, grow = "right",
    countAt = "corner", showCount = true, low = 5, radius = 0, waterFirst = false,
    font = FONTS[1][2], fontSize = 12, outline = true,
    color = { 1, 1, 1, 1 }, lowColor = { 1, 0.4, 0.4, 1 },
}

-- Buff check: who in the group is missing a buff somebody here can hand out.
DEFAULTS.buffs = {
    show = false, locked = true, x = -300, y = 0, size = 18, fontSize = 12, outline = true,
    font = FONTS[1][2], color = { 1, 0.5, 0.5, 1 }, onlyMissing = false, lowCount = 5,
    skip = {}, -- [check key] = true: leave that one out
}

-- the old "Target health beside it" switch; useProfile turns it into Enemy Health beside you
DEFAULTS.regular.bars.health.target = false
DEFAULTS.regular.hidePlayerFrame = false -- hide Blizzard's player unit frame
DEFAULTS.regular.hideTargetFrame = false -- hide Blizzard's target unit frame
DEFAULTS.regular.hideBlizzCastbar = false -- hide Blizzard's player cast bar
DEFAULTS.regular.playerMenu = false      -- right-click on the bars opens the player menu
DEFAULTS.regular.targetMenu = true       -- right-click on the enemy health bar opens the target's menu
DEFAULTS.regular.petMenu = true          -- ... on the pet bar, your pet's
DEFAULTS.regular.totMenu = true          -- ... on target of target, its menu
DEFAULTS.regular.playerTarget = false    -- left-click on the bars targets yourself
DEFAULTS.regular.playerMouseover = false -- hovering the bars makes you @mouseover
DEFAULTS.regular.highlight = { show = false, color = { 1, 1, 1, 0.25 } } -- overlay while hovered

------------------------------------------------------------------------------------------
-- Colors: one palette for the whole profile. A bar picks which of these it wears (or a color of
-- its own); anything new that needs a class, power, health or cast color takes it from here.
-- borderShade: how a "same as bar" border differs from the bar, -100 (black) to 100 (white).
------------------------------------------------------------------------------------------
ns.CLASS_ORDER = { { "WARRIOR", "Warrior" }, { "PALADIN", "Paladin" }, { "HUNTER", "Hunter" }, { "ROGUE", "Rogue" },
    { "PRIEST", "Priest" }, { "DEATHKNIGHT", "Death Knight" }, { "SHAMAN", "Shaman" }, { "MAGE", "Mage" },
    { "WARLOCK", "Warlock" }, { "MONK", "Monk" }, { "DRUID", "Druid" }, { "DEMONHUNTER", "Demon Hunter" },
    { "EVOKER", "Evoker" } }
ns.POWER_ORDER = { { "MANA", "Mana" }, { "RAGE", "Rage" }, { "ENERGY", "Energy" }, { "FOCUS", "Focus" },
    { "RUNIC_POWER", "Runic power" }, { "LUNAR_POWER", "Astral power" }, { "MAELSTROM", "Maelstrom" },
    { "INSANITY", "Insanity" }, { "FURY", "Fury" }, { "PAIN", "Pain" } }
do
    local CLASS = { WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 },
        ROGUE = { 1, 0.96, 0.41 }, PRIEST = { 1, 1, 1 }, DEATHKNIGHT = { 0.77, 0.12, 0.23 },
        SHAMAN = { 0, 0.44, 0.87 }, MAGE = { 0.25, 0.78, 0.92 }, WARLOCK = { 0.53, 0.53, 0.93 },
        MONK = { 0, 1, 0.6 }, DRUID = { 1, 0.49, 0.04 }, DEMONHUNTER = { 0.64, 0.19, 0.79 },
        EVOKER = { 0.2, 0.58, 0.5 } }
    local POWER = { MANA = { 0, 0, 1 }, RAGE = { 1, 0, 0 }, ENERGY = { 1, 1, 0 }, FOCUS = { 1, 0.5, 0.25 },
        RUNIC_POWER = { 0, 0.82, 1 }, LUNAR_POWER = { 0.3, 0.52, 0.9 }, MAELSTROM = { 0, 0.5, 1 },
        INSANITY = { 0.4, 0, 0.8 }, FURY = { 0.79, 0.26, 0.99 }, PAIN = { 1, 0.61, 0 } }
    local p = { class = {}, power = {} }
    for token, c in pairs(CLASS) do -- the game's own, where it says
        local ok, cc = pcall(function() return C_ClassColor and C_ClassColor.GetClassColor(token) or RAID_CLASS_COLORS[token] end)
        p.class[token] = ok and cc and { cc.r, cc.g, cc.b, 1 } or { c[1], c[2], c[3], 1 }
    end
    for token, c in pairs(POWER) do p.power[token] = { c[1], c[2], c[3], 1 } end
    p.health = { 0.2, 0.8, 0.2, 1 }
    p.reaction = { hostile = { 0.85, 0.2, 0.2, 1 }, neutral = { 0.95, 0.8, 0.2, 1 }, friendly = { 0.2, 0.8, 0.2, 1 } }
    -- your cast bar: casting / channeling; your target's: what kind of cast (auto color)
    p.cast = { cast = { 1, 0.7, 0, 1 }, channel = { 0.3, 0.7, 1, 1 }, harm = { 0.9, 0.3, 0.2, 1 },
        heal = { 0.2, 0.9, 0.3, 1 }, locked = { 0.6, 0.6, 0.65, 1 } }
    p.borderShade = 25
    p.moved = false -- useProfile has moved the per-bar power and cast colors in here (once)
    DEFAULTS.colors = p
end

local function merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            merge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

------------------------------------------------------------------------------------------
-- Data sources
------------------------------------------------------------------------------------------
-- store = WolfpackAddonDB, account-wide: { profiles = { [name] = settings }, chars = { [char] = name } }
-- db = the active profile's settings.
local changed, placeMini, useProfile, bf, mg, hn, wl, we, lt, mc, ft, seedFromBaked

-- Bars that only show while they are doing something (cast, swing) stay visible while the bars
-- are unlocked or the options are open, so they can be placed.
function ns.previewing() return not db.locked or ns.configOpen end
local CLASS_POWER = {
    ROGUE = PT.ComboPoints, DRUID = PT.ComboPoints, PALADIN = PT.HolyPower, WARLOCK = PT.SoulShards,
    MONK = PT.Chi, MAGE = PT.ArcaneCharges, EVOKER = PT.Essence,
}

local function classPower()
    if class == "DRUID" and UnitPowerType("player") ~= PT.Energy then return nil end -- cat form only
    return CLASS_POWER[class]
end

-- state() -> shown, segment count. value(unit) -> current, max (both possibly secret).
------------------------------------------------------------------------------------------
-- Flight times. Nothing in the game will say how long a taxi ride takes -- the flight point
-- knows the price and nothing else -- so the first ride on a route is timed and written down,
-- account-wide, and every ride after that counts down from it. A route you have never flown
-- shows the time so far instead of a guess.
ft = { }
ns.ft = ft

function ft.flying()
    local ok, on = pcall(UnitOnTaxi, "player")
    return ok and on == true
end

-- The name of the flight point you are standing on, and of one on the map by its slot.
function ft.nodeName(slot)
    local ok, name = pcall(function()
        if TaxiNodeName then return TaxiNodeName(slot) end
    end)
    if ok and type(name) == "string" and name ~= "" then return name end
    local ok2, found = pcall(function()
        local map = C_Map.GetBestMapForUnit("player")
        for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(map) or {}) do
            if node.slotIndex == slot then return node.name end
        end
    end)
    return ok2 and found or nil
end

function ft.here()
    local ok, name = pcall(function()
        local map = C_Map.GetBestMapForUnit("player")
        for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(map) or {}) do
            if node.state == 0 or node.state == Enum.FlightPathState.Current then return node.name end
        end
    end)
    if ok and type(name) == "string" then return name end
    local ok2, zone = pcall(GetSubZoneText)
    return (ok2 and zone ~= "" and zone) or (select(2, pcall(GetZoneText)))
end

-- Clicking a flight point is the only moment both ends of the route are known. Which call the
-- flight map makes has moved between builds, so every one of them is hooked and whichever fires
-- wins; ft.hooked says which were there to hook at all.
function ft.taking(slot)
    local from, to = ft.here(), ft.nodeName(slot)
    if not to then return end -- a call that told us nothing is not a route
    ft.route = { from = from or "?", to = to }
    ft.caught = GetTime()
end

function ft.hook()
    ft.hooked = {}
    for _, name in ipairs({ "TakeTaxiNode", "TaxiNodeOnButtonEnter" }) do
        if type(_G[name]) == "function" then ft.hooked[#ft.hooked + 1] = name end
    end
    pcall(hooksecurefunc, "TakeTaxiNode", function(slot) safe(ft.taking, slot) end)
    -- some builds route the click through the map frame's own handler instead
    pcall(function()
        if TaxiFrame and TaxiFrame.TakeTaxiNode then
            hooksecurefunc(TaxiFrame, "TakeTaxiNode", function(_, slot) safe(ft.taking, slot) end)
            ft.hooked[#ft.hooked + 1] = "TaxiFrame:TakeTaxiNode"
        end
    end)
end

function ft.key()
    return ft.route and (ft.route.from .. " > " .. ft.route.to) or nil
end

function ft.known(key)
    return store and store.flights and store.flights[key or ft.key() or ""] or nil
end

-- How long this ride takes and how far into it you are. The first is nil on a route never
-- flown; the second is always the time since takeoff, so the two never mean different things.
function ft.progress()
    if not ft.startedAt then return nil, nil end
    return ft.total, GetTime() - ft.startedAt
end

function ft.tick()
    local on = ft.flying()
    if on and not ft.startedAt then
        ft.startedAt, ft.total = GetTime(), ft.known()
        ft.moved = true
    elseif not on and ft.startedAt then
        ft.moved = true
        local flown, key = GetTime() - ft.startedAt, ft.key()
        -- a ride under five seconds is somebody dismounting, not a route
        if key and flown > 5 and store then
            store.flights = store.flights or {}
            store.flights[key] = math.floor(flown + 0.5)
        end
        ft.startedAt, ft.total, ft.route = nil, nil, nil
    end
    return ft.moved -- set on the tick where the ride began or ended, cleared by the ticker
end

local BARS = {
    health = {
        label = "Health",
        state = function() return true, 1 end,
        value = function(unit) return UnitHealth(unit), UnitHealthMax(unit) end,
    },
    power = {
        label = "Power",
        state = function() return true, 1 end,
        value = function()
            local t = UnitPowerType("player")
            return UnitPower("player", t), UnitPowerMax("player", t)
        end,
    },
    combo = {
        label = "Combo Points",
        state = function()
            local t = classPower()
            if not t then return false end
            local max = UnitPowerMax("player", t)
            -- ponytail: max is secret on the Forever beta, so assume 5 combo points and hide other
            -- class resources; drop this line once Blizzard un-secrets class resources.
            if isSecret(max) then max = t == PT.ComboPoints and 5 or 0 end
            return max > 0, max
        end,
        value = function() return UnitPower("player", classPower()) end,
    },
    pethealth = {
        label = "Pet Health",
        state = function() return UnitExists("pet"), 1 end,
        value = function() return UnitHealth("pet"), UnitHealthMax("pet") end,
    },
    castbar = {
        label = "Cast Bar",
        -- only while casting: the bars below close the gap. ns.previewing keeps it visible while
        -- the bars are unlocked or the options are open, for placing it.
        state = function()
            return (ns.previewing() or UnitCastingInfo("player") or UnitChannelInfo("player")) and true or false, 1
        end,
    },
    absorb = {
        label = "Shield",
        -- How much damage the absorb shields still swallow. The amount is secret like health is,
        -- so it can only be passed on, never read: `absorb.have` tracks whether a snapshot of the
        -- shield's full size exists, because testing the snapshot itself would be a read.
        state = function() return true, 1 end,
        value = function(unit)
            local ok, points = pcall(UnitGetTotalAbsorbs, unit)
            local max
            if unit == "player" and absorb.have then max = absorb.max else max = UnitHealthMax(unit) end
            return ok and points or 0, max
        end,
    },
    totems = {
        label = "Totems",
        state = function() return class == "SHAMAN", #TOTEM_SLOTS end,
    },
    swing = {
        label = "Swing Timer",
        state = function() return true, 1 end, -- a row per ticked weapon, each only while that one swings
    },
    targetcast = {
        label = "Enemy Cast",
        -- Only while your target is casting. What comes back can be secret on this client, and
        -- a secret may not even be tested for truth -- so the test is wrapped, and a refusal is
        -- taken as a yes: the game only has something to hide when there is something there.
        state = function()
            return (ns.previewing() or ns.targetCasting == true) and true or false, 1
        end,
    },
    flight = {
        label = "Flight",
        -- only while the griffin has you. Nobody will say how long a route takes, so the first
        -- time you fly one it is timed and remembered, and after that it counts down.
        state = function() return (ns.previewing() or ft.flying()) and true or false, 1 end,
    },
    enemyhealth = {
        label = "Enemy Health",
        -- while you have a target, and while placing the bars
        state = function() return (UnitExists("target") or ns.previewing()) and true or false, 1 end,
        value = function(unit)
            if not UnitExists(unit) then return 1, 1 end -- previewing: a full bar
            return UnitHealth(unit), UnitHealthMax(unit)
        end,
    },
    tothealth = {
        label = "Target of Target",
        state = function() return (UnitExists("targettarget") or ns.previewing()) and true or false, 1 end,
        value = function(unit)
            if not UnitExists(unit) then return 1, 1 end -- previewing: a full bar
            return UnitHealth(unit), UnitHealthMax(unit)
        end,
    },
    druidmana = {
        label = "Druid Mana",
        -- in caster form the power bar already is mana
        state = function() return class == "DRUID" and UnitPowerType("player") ~= PT.Mana, 1 end,
        value = function() return UnitPower("player", PT.Mana), UnitPowerMax("player", PT.Mana) end,
    },
}

------------------------------------------------------------------------------------------
-- Bars
------------------------------------------------------------------------------------------
local frames = {}
ns.frames = frames

local anchor = CreateFrame("Frame", "WolfpackAddonFrame", UIParent)
anchor:SetMovable(true)
anchor:SetClampedToScreen(true)

-- The pinned edge decides which way the stack grows when a bar joins or leaves: pin the top and
-- it grows down, pin the bottom and it grows up.
local function growEdge(L) return L.grow == "up" and "BOTTOM" or "TOP" end

local function place()
    anchor:ClearAllPoints()
    anchor:SetPoint(growEdge(db.regular), UIParent, "CENTER", db.regular.x, db.regular.y)
end

-- Position = the pinned edge's center, in pixels from the screen center.
local function coords()
    local ux, uy = UIParent:GetCenter()
    local edge = db.regular.grow == "up" and anchor:GetBottom() or anchor:GetTop()
    return math.floor(anchor:GetCenter() - ux + 0.5), math.floor(edge - uy + 0.5)
end

-- Drag handle shown while unlocked; sits above the bars.
local HINT = "X %d  Y %d  -  drag to move, right-click for options"
local mover = CreateFrame("Frame", nil, anchor)
mover:SetAllPoints()
mover:SetFrameLevel(anchor:GetFrameLevel() + 20)
mover:Hide()
mover:EnableMouse(true)
mover:RegisterForDrag("LeftButton")
local moverTex = mover:CreateTexture(nil, "OVERLAY")
moverTex:SetAllPoints()
moverTex:SetColorTexture(0.2, 1, 0.2, 0.3)
local moverHint = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
moverHint:SetPoint("BOTTOM", mover, "TOP", 0, 2)
local moving -- true while the group is being dragged: Refresh must not re-place it then
mover:SetScript("OnDragStart", function()
    moving = true
    anchor:StartMoving()
    mover:SetScript("OnUpdate", function() moverHint:SetFormattedText(HINT, coords()) end) -- live coordinates
end)
mover:SetScript("OnDragStop", function()
    anchor:StopMovingOrSizing()
    moving = nil
    mover:SetScript("OnUpdate", nil)
    db.regular.x, db.regular.y = coords()
    place()
    changed()
end)
mover:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then ns.ToggleConfig() end
end)

-- Every bar exists twice: in the regular stack and in a second stack under the target nameplate.
local plateAnchor = CreateFrame("Frame", nil, anchor)
local plateFrames = {}
ns.plateFrames = plateFrames

local function newBar(parent, key, mode)
    local f = CreateFrame("Frame", nil, parent)
    f.key, f.mode, f.segs = key, mode, {}
    return f
end

local swingFrames = { regular = {}, nameplate = {} }
ns.swingFrames = swingFrames

for key in pairs(BARS) do
    frames[key] = newBar(anchor, key, "regular")
    plateFrames[key] = newBar(plateAnchor, key, "nameplate")
end
-- Enemy health reads your target; its resource bar sits inside it and wears its look
for _, set in ipairs({ frames, plateFrames }) do
    set.tothealth.unit = "targettarget"
    local f = set.enemyhealth
    f.unit = "target"
    f.resFrame = newBar(f, "enemyhealth", f.mode)
    f.resFrame.unit, f.resFrame.res = "target", true
    f.resFrame:Hide() -- until laid out: power events fill only shown bars
end
for i in ipairs(SWING_TYPES) do
    swingFrames.regular[i] = newBar(anchor, "swing", "regular")
    swingFrames.regular[i].swing = i
    swingFrames.nameplate[i] = newBar(plateAnchor, "swing", "nameplate")
    swingFrames.nameplate[i].swing = i
end

local MAX_STOPS = 8

-- Gradient points in drawing order. "left" and "up" mirror the positions.
local function sortedStops(c)
    local out = {}
    local flip = c.direction == "left" or c.direction == "up"
    for _, stop in ipairs(c.stops) do
        out[#out + 1] = { pos = flip and 100 - stop.pos or stop.pos, color = stop.color }
    end
    table.sort(out, function(a, b) return a.pos < b.pos end)
    return out
end

-- WoW gradients take two colors, so more points are drawn as one slice per pair, masked by the
-- bar's own fill so they only show over the filled part (no math on hidden health/power values).
local function paintSlices(s, c, w, h)
    local stops = sortedStops(c)
    local vertical = c.direction == "down" or c.direction == "up"
    s.fillMask:SetAllPoints(s:GetStatusBarTexture())
    for i = 1, math.max(#stops - 1, #s.slices) do
        local t = s.slices[i]
        if i >= #stops then
            if t then t:Hide() end
        else
            if not t then
                t = s:CreateTexture(nil, "ARTWORK", nil, 1)
                t:AddMaskTexture(s.fillMask)
                s.slices[i] = t
            end
            local from, to = stops[i], stops[i + 1]
            t:SetTexture(c.texture)
            t:ClearAllPoints()
            if vertical then
                t:SetPoint("TOPLEFT", s, "TOPLEFT", 0, -h * from.pos / 100)
                t:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, -h * to.pos / 100)
                t:SetGradient("VERTICAL", CreateColor(unpack(to.color)), CreateColor(unpack(from.color)))
            else
                t:SetPoint("TOPLEFT", s, "TOPLEFT", w * from.pos / 100, 0)
                t:SetPoint("BOTTOMRIGHT", s, "BOTTOMLEFT", w * to.pos / 100, 0)
                t:SetGradient("HORIZONTAL", CreateColor(unpack(from.color)), CreateColor(unpack(to.color)))
            end
            t:Show()
        end
    end
end

local function paint(s, c, r, g, b, w, h)
    s:SetStatusBarTexture(c.texture) -- before colors: a new texture resets them
    if c.gradient and #c.stops > 1 then
        s:SetStatusBarColor(1, 1, 1, 0) -- the slices do the drawing; the fill only shapes them
        paintSlices(s, c, w, h)
    else
        for _, t in ipairs(s.slices) do t:Hide() end
        s:SetStatusBarColor(r, g, b, c.color[4])
    end
end

-- Rounded corners: WoW has no border-radius, so textures get a mask cut from a rounded
-- rectangle. Media/Round/r<N>.tga has corners of exactly N px (1-50); nine-sliced with N px
-- margins, the corners draw at that size on any bar size.
local MASK_DIR = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Round\\r"
local MAX_RADIUS = 50

local function newMask(owner)
    return owner:CreateMaskTexture()
end

-- Corner radius r on a w x h area; 0 = square (mask removed). Capped at half the short side,
-- which is also what "pill" asks for (r = huge).
local function round(tex, m, r, w, h)
    r = math.floor(math.min(r, w / 2, h / 2, MAX_RADIUS))
    if r > 0 and m.r ~= r then
        m:SetTexture(MASK_DIR .. r .. ".tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetTextureSliceMargins(r, r, r, r)
        m.r = r
    end
    if (r > 0) ~= (tex.cpdMask == m) then
        if r > 0 then tex:AddMaskTexture(m) else tex:RemoveMaskTexture(m) end
        tex.cpdMask = r > 0 and m or nil
    end
end

local hovered -- cursor over the Combat Display group (highlight option)

-- Class color of a unit, from the palette; nil for NPCs other than you (they have classes too,
-- which would look random).
local function classRGB(unit)
    if unit ~= "player" and not UnitIsPlayer(unit) then return end
    local _, token = UnitClass(unit)
    local c = token and db.colors.class[token]
    if c then return c[1], c[2], c[3] end
end

-- A power's color from the palette (the game's own for one it has no swatch for).
function ns.powerRGB(token)
    local c, pc = db.colors.power[token], PowerBarColor and PowerBarColor[token]
    if c then return c[1], c[2], c[3] end
    if pc then return pc.r, pc.g, pc.b end
end

-- How the unit stands to you: hostile, neutral or friendly, from the palette; nil if unknown.
function ns.reactionRGB(unit)
    local ok, r = pcall(UnitReaction, unit, "player")
    if not (ok and readable(r) and type(r) == "number") then return end
    local c = db.colors.reaction[r <= 3 and "hostile" or r == 4 and "neutral" or "friendly"]
    return c[1], c[2], c[3]
end

-- A "same as bar" border: the bar's color, lighter or darker by the palette's border shade.
function ns.shade(r, g, b)
    local s = (db.colors.borderShade or 0) / 100
    if s >= 0 then return r + (1 - r) * s, g + (1 - g) * s, b + (1 - b) * s end
    return r * (1 + s), g * (1 + s), b * (1 + s)
end

-- The palette color a bar wears in its mode, or nil (then its own color). f.castKind / f.channel:
-- what the cast bars are showing right now.
function ns.modeRGB(f, c)
    local m, unit = c.colorMode, f.unit or "player"
    if m == "health" then
        local h = db.colors.health
        return h[1], h[2], h[3]
    elseif m == "power" then
        local token = f.key == "druidmana" and "MANA" or select(2, UnitPowerType(unit))
        return ns.powerRGB(token)
    elseif m == "class" then
        local r, g, b = classRGB(unit)
        if r or (f.key ~= "enemyhealth" and f.key ~= "tothealth") then return r, g, b end
        return ns.reactionRGB(unit) -- an NPC has no class color of its own: how it stands to you
    elseif m == "reaction" then
        return ns.reactionRGB(unit)
    elseif m == "auto" or m == "cast" then
        local kind = m == "auto" and (f.castKind or "harm") or (f.channel and "channel" or "cast")
        local k = db.colors.cast[kind]
        return k[1], k[2], k[3]
    end
end

-- A bar's fill and border colors after the color modes. Alpha always comes from the swatch.
local function barColors(f, c)
    local r, g, b = unpack(c.color)
    local mr, mg, mb = ns.modeRGB(f, c)
    if mr then r, g, b = mr, mg, mb end
    local br, bg, bb, ba = unpack(c.borderColor)
    if c.borderMode ~= "custom" then -- the bar's color, shaded, so the edge reads
        local first = c.gradient and sortedStops(c)[1] -- a gradient: where the fill starts
        if first then
            br, bg, bb = ns.shade(first.color[1], first.color[2], first.color[3])
        else
            br, bg, bb = ns.shade(r, g, b)
        end
    end
    return r, g, b, br, bg, bb, ba
end

-- A cast bar's color changes with the cast, after layout: recolor the fill and its border.
function ns.wearColor(f, c)
    local r, g, b = ns.modeRGB(f, c)
    if not r or c.gradient then return end
    local s = f.segs[1]
    s:SetStatusBarColor(r, g, b, c.color[4] or 1)
    if c.borderMode ~= "custom" then
        local br, bg, bb = ns.shade(r, g, b)
        s.border:SetColorTexture(br, bg, bb, c.borderColor[4])
    end
end

-- over: settings that replace the bar's own for this layout (enemy health's height while it sits
-- beside your health, its resource bar's height and colors)
local function layoutBar(f, n, width, over)
    local c = db[f.mode].bars[f.key]
    if over then c = setmetatable(over, { __index = c }) end
    width = width or c.width
    f.width = width
    local r, g, b, br, bg, bb, ba = barColors(f, c)
    -- Cast bar spell icon: a square at one end, inside the bar's width. Both cast bars have one.
    local lead, iconSpace = 0, 0
    if f.key == "castbar" or f.key == "targetcast" then
        f.icon = f.icon or f:CreateTexture(nil, "ARTWORK")
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the icon's built-in border
        f.icon:SetSize(c.height, c.height)
        f.icon:ClearAllPoints()
        f.icon:SetPoint(c.iconSide == "right" and "RIGHT" or "LEFT", f)
        f.icon:SetShown(c.icon and true or false)
        if c.icon then
            iconSpace = c.height + PIP_GAP
            if c.iconSide ~= "right" then lead = iconSpace end
        end
    end
    f:SetSize(width, c.height)
    local w = (width - iconSpace - (n - 1) * PIP_GAP) / n
    for i = 1, math.max(n, #f.segs) do
        local s = f.segs[i]
        if i > n then
            s:Hide()
        else
            if not s then
                s = CreateFrame("StatusBar", nil, f)
                s.bg = s:CreateTexture(nil, "BACKGROUND")
                s.bg:SetAllPoints()
                s.bg:SetColorTexture(0, 0, 0, 0.5) -- recolored per bar below
                s.border = s:CreateTexture(nil, "BACKGROUND", nil, -8) -- behind the background
                s.mask, s.borderMask = newMask(s), newMask(s)
                s.slices = {}
                s.fillMask = s:CreateMaskTexture() -- the filled part, for the gradient slices
                s.fillMask:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                s.mask:SetAllPoints(s)
                s.borderMask:SetAllPoints(s.border)
                s.hl = s:CreateTexture(nil, "OVERLAY", nil, -8) -- hover highlight; text draws above it
                s.hl:SetAllPoints(s.border)
                f.segs[i] = s
            end
            -- The border sits inside the bar's size (like CSS border-box); the bar is inset by it.
            local t = math.min(c.borderSize, (c.height - 1) / 2, (w - 1) / 2)
            local iw, ih = w - 2 * t, c.height - 2 * t
            f.segWidth = iw
            s:SetSize(iw, ih)
            s:SetPoint("LEFT", f, "LEFT", lead + (i - 1) * (w + PIP_GAP) + t, 0)
            s:SetMinMaxValues(i - 1, i) -- pip range; single bars get their real max in ns.fill()
            s.bg:SetColorTexture(unpack(c.bgColor))
            local sr, sg, sb = br, bg, bb
            if f.key == "totems" then -- each segment wears its element's color, border included
                local col = c.slotColors[c.slots[i]]
                paint(s, c, col[1], col[2], col[3], w, c.height)
                if c.borderMode ~= "custom" and not c.gradient then sr, sg, sb = ns.shade(col[1], col[2], col[3]) end
            else
                paint(s, c, r, g, b, w, c.height)
            end
            s.border:SetShown(t > 0)
            s.border:SetPoint("TOPLEFT", s, "TOPLEFT", -t, t)
            s.border:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", t, -t)
            s.border:SetColorTexture(sr, sg, sb, ba)
            local radius = c.radius == "pill" and math.huge or c.radius
            round(s.border, s.borderMask, radius, w, c.height)
            s.hl:SetColorTexture(unpack(db.regular.highlight.color))
            s.hl:SetShown((f.mode == "regular" and hovered) or false)
            round(s.hl, s.borderMask, radius, w, c.height)
            local inner = math.max(radius - t, 0) -- inner corners follow the outer ones
            round(s.bg, s.mask, inner, iw, ih)
            round(s:GetStatusBarTexture(), s.mask, inner, iw, ih)
            s:Show()
        end
    end
    -- Prediction overlay: incoming heals grow right from the health fill, a cast's cost grows
    -- left from the power fill. Both hang off the fill texture, so no value is ever read to
    -- place them, and a frame over the bar clips whatever runs past its edge. Only that frame
    -- clips: the bar itself must not, or every icon, buff and text hung outside it is cut off.
    local over = (f.key == "health" and c.heal) or (f.key == "power" and c.cost)
    if over and n == 1 then
        local seg = f.segs[1]
        if not f.over then
            local clip = CreateFrame("Frame", nil, f)
            clip:SetAllPoints(f)
            clip:SetClipsChildren(true)
            f.over = CreateFrame("StatusBar", nil, clip)
        end
        local o, col = f.over, f.key == "health" and c.healColor or c.costColor
        o:GetParent():SetFrameLevel(seg:GetFrameLevel() + 1)
        o:SetFrameLevel(seg:GetFrameLevel() + 1)
        o:SetStatusBarTexture(c.texture)
        o:SetStatusBarColor(col[1], col[2], col[3], col[4])
        o:SetSize(seg:GetWidth(), seg:GetHeight())
        o:ClearAllPoints()
        o:SetReverseFill(f.key == "power")
        o:SetPoint(f.key == "power" and "RIGHT" or "LEFT", seg:GetStatusBarTexture(),
            f.key == "power" and "RIGHT" or "RIGHT", 0, 0)
        o:Show()
    elseif f.over then
        f.over:Hide()
    end
    if not f.text then
        f.text = f.segs[1]:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.text:SetPoint("CENTER") -- centered on the bar itself (not the cast bar's icon)
    end
    f.text:SetShown(c.text and n == 1)
    local flags = c.outline and "OUTLINE" or ""
    if not f.text:SetFont(c.font, c.fontSize, flags) then f.text:SetFont(FONTS[1][2], c.fontSize, flags) end
    f.text:SetTextColor(unpack(c.textColor))
    if ns.TEXT_BARS[f.key] and not f.res then -- three numbers of its own instead
        f.text:Hide()
        ns.layoutTexts(f, c, n)
    end
    f.n = n
end

local function setText(fs, v) fs:SetText(AbbreviateNumbers(v)) end

-- The cast bar fills from the game's own cast duration object (no per-frame Lua): casts fill
-- up, channels drain. Not casting: the whole bar, border included, goes invisible.
local TIMER_ELAPSED, TIMER_REMAINING = 0, 1 -- Enum.StatusBarTimerDirection
local function fillCast(f)
    local name, _, icon = UnitCastingInfo("player")
    local duration, direction = name and UnitCastingDuration("player"), TIMER_ELAPSED
    if not name then
        name, _, icon = UnitChannelInfo("player")
        duration, direction = name and UnitChannelDuration("player"), TIMER_REMAINING
    end
    if not name then -- previewing (the bar only shows at all while casting)
        f.text:SetText(BARS.castbar.label)
        f.icon:SetTexture(134400) -- Interface/ICONS/INV_Misc_QuestionMark
        return
    end
    if duration then f.segs[1]:SetTimerDuration(duration, 0, direction) end
    f.text:SetText(name)
    f.icon:SetTexture(icon)
    f.channel = direction == TIMER_REMAINING
    ns.wearColor(f, db[f.mode].bars.castbar)
end

-- What your target is casting, as far as anything will say. Whether it can be stopped the game
-- tells us outright. Whether it heals it does not, and no list of spells on Wowhead separates
-- heals from buffs cleanly, so these are matched by name -- the names that matter are the ones
-- a mob healer casts at you from across the room.
-- Whether your target is casting is tracked from the events rather than asked for: the events
-- say which unit plainly, where the cast itself comes back secret and cannot even be tested for
-- truth. A refusal to read is not the same as a cast, which is what made the bar sit there.
ns.targetCasting = false

function ns.watchTargetCast(event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        ns.targetCasting, ns.targetChannelling = false, false
        return true
    end
    if unit ~= "target" then return false end
    if event == "UNIT_SPELLCAST_START" then
        ns.targetCasting, ns.targetChannelling = true, false
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        ns.targetCasting, ns.targetChannelling = true, true
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_SUCCEEDED" then
        ns.targetCasting = false
    else
        return false
    end
    return true
end

ns.HEALING_CASTS = {}
for _, name in ipairs({ "Heal", "Lesser Heal", "Greater Heal", "Flash Heal", "Renew",
    "Prayer of Healing", "Holy Light", "Flash of Light", "Holy Nova", "Healing Wave",
    "Lesser Healing Wave", "Chain Heal", "Healing Touch", "Regrowth", "Rejuvenation",
    "Mend Pet", "Dark Mending", "Healing Ward", "Healing Totem", "Renew Life",
    "Lay on Hands", "Divine Shield", "Shield of Reckoning", "Bandage", "First Aid",
    "Mending", "Greater Healing Wave", "Holy Smite Heal" }) do
    ns.HEALING_CASTS[name:lower()] = true
end

-- "locked" when it cannot be stopped, "heal" when it mends, "harm" for the rest. Either of
-- those can arrive secret, which may be passed on but never looked at -- so an unreadable one
-- simply does not decide anything.
function ns.castKind(name, locked)
    if readable(locked) and locked == true then return "locked" end
    if readable(name) and type(name) == "string" and ns.HEALING_CASTS[name:lower()] then
        return "heal"
    end
    return "harm"
end

-- Your target's cast, drained by the game's own duration object where there is one.
function ns.fillTargetCast(f)
    -- Nothing here is compared, tested for truth, or checked against nil: on this client a
    -- target's cast comes back secret, and a secret may be handed to a bar or a font string but
    -- not looked at in any way. Which of the two calls to ask, and whether anything is being
    -- cast at all, come from the events instead -- asking the cast would mean reading it.
    local channel = ns.targetChannelling == true
    local info = { pcall(channel and UnitChannelInfo or UnitCastingInfo, "target") }
    local name, icon = info[2], info[4]
    local locked = info[channel and 8 or 9]  -- picked by index: choosing it with `and` reads it

    -- the color is only known once the cast is read, which is after the bar was laid out
    local function wear(kind)
        f.castKind, f.channel = kind, channel
        local c = db[f.mode] and db[f.mode].bars.targetcast
        if c then ns.wearColor(f, c) end
    end

    if ns.targetCasting ~= true then -- previewing, or nothing being cast
        f.text:SetText(BARS.targetcast.label)
        f.icon:SetTexture(134400)
        f.segs[1]:SetMinMaxValues(0, 1)
        f.segs[1]:SetValue(ns.previewing() and 1 or 0)
        wear("harm")
        return
    end

    -- The duration object is what drains the bar, in C. Whether one came back is counted, not
    -- compared: a call that returned nothing leaves the table one long.
    local got = { pcall(channel and UnitChannelDuration or UnitCastingDuration, "target") }
    local ticking = #got > 1 and pcall(f.segs[1].SetTimerDuration, f.segs[1], got[2], 0,
        channel and TIMER_REMAINING or TIMER_ELAPSED)
    if not ticking then -- nobody will say how long: an empty bar is less of a lie than a full one
        f.segs[1]:SetMinMaxValues(0, 1)
        f.segs[1]:SetValue(0)
    end
    pcall(f.text.SetText, f.text, name)        -- a secret name still draws
    pcall(f.icon.SetTexture, f.icon, icon)
    wear(ns.castKind(name, locked))
end

-- The flight bar drains for a route we have flown before, and counts up the first time so the
-- ride is at least measured while it happens.
local function fillFlight(f)
    local total, gone = ft.progress()
    local function clock(t)
        return ("%d:%02d"):format(math.floor(t / 60), math.floor(t % 60))
    end
    if not gone then -- previewing, on the ground
        f.segs[1]:SetMinMaxValues(0, 1)
        f.segs[1]:SetValue(1)
        f.text:SetText(BARS.flight.label)
        return
    end
    if total then
        f.segs[1]:SetMinMaxValues(0, total)
        f.segs[1]:SetValue(math.max(total - gone, 0))
        f.text:SetText(clock(math.max(total - gone, 0)))
    else -- never flown this one: a full bar, and the time so far
        f.segs[1]:SetMinMaxValues(0, 1)
        f.segs[1]:SetValue(1)
        f.text:SetText(clock(gone) .. (ft.route and " so far" or " -- route not caught"))
    end
end

-- Swing timers come from the game's own PLAYER_SWING event (no combat log needed).
local swingState = {} -- [swing type] = { start, duration }

local function swingActive(kind)
    local now = GetTime()
    if kind then
        local st = swingState[kind]
        return (st and now < st.start + st.duration) and true or false
    end
    for _, st in pairs(swingState) do
        if now < st.start + st.duration then return true end
    end
    return false
end

local function fillSwing(f)
    local kind = SWING_TYPES[f.swing]
    local st = swingState[kind[3]]
    if not swingActive(kind[3]) then -- preview: a full bar, not the last swing's frozen fill
        f.segs[1]:SetMinMaxValues(0, 1)
        f.segs[1]:SetValue(1)
        f.text:SetText(kind[2])
        return
    end
    local elapsed = GetTime() - st.start
    f.segs[1]:SetMinMaxValues(0, st.duration)
    f.segs[1]:SetValue(elapsed)
    f.text:SetText(string.format("%.1f", st.duration - elapsed))
end

-- The overlay shares the bar's scale, so the same max goes in: incoming heals for health, the
-- cost of the cast in flight for power.
local function fillOverlay(f, max)
    f.over:SetMinMaxValues(0, max)
    if f.key == "power" then
        if castCost.have then f.over:SetValue(castCost.value) else f.over:SetValue(0) end
        return
    end
    local unit = f.unit or "player"
    -- the calculator is the good way, where the client has one
    if healCalc and UnitGetDetailedHealPrediction then
        local ok = pcall(function()
            healCalc:SetIncomingHealClampMode(0) -- 0 = stop at missing health, no overheal
            healCalc:SetIncomingHealOverflowPercent(1.0)
            UnitGetDetailedHealPrediction(unit, "player", healCalc)
            f.over:SetMinMaxValues(0, healCalc:GetMaximumHealth())
            f.over:SetValue(healCalc:GetIncomingHeals())
        end)
        if ok then return end
    end
    -- and the plain one otherwise. The number may be secret, which a bar can still be given.
    local ok, heals = pcall(function()
        if UnitGetIncomingHeals then return UnitGetIncomingHeals(unit) end
    end)
    if ok and heals ~= nil then
        f.over:SetMinMaxValues(0, max)
        f.over:SetValue(heals)
    else
        f.over:SetValue(0)
    end
end

-- on the namespace rather than a local: this chunk is at Lua's 200-local ceiling, and the
-- flight ticker needs to reach it
function ns.fill(f)
    if f.key == "castbar" then return fillCast(f) end
    if f.key == "targetcast" then return ns.fillTargetCast(f) end
    if f.key == "flight" then return fillFlight(f) end
    if f.key == "swing" then return fillSwing(f) end
    if f.key == "totems" then -- the bar drains itself from the duration object, in C
        local c = db[f.mode].bars[f.key]
        for i = 1, f.n do
            local d = totemDuration(c.slots[i])
            if d then
                f.segs[i]:SetTimerDuration(d, 0, TIMER_REMAINING)
            else -- no such API on this build: show a full bar while placing it, nothing otherwise
                f.segs[i]:SetMinMaxValues(0, 1)
                f.segs[i]:SetValue(ns.previewing() and 1 or 0)
            end
        end
        return
    end
    local v, max = (f.res and ns.resValue or BARS[f.key].value)(f.unit or "player")
    -- an empty enemy resource (none at all, or nothing left) goes invisible, border and all. A
    -- secret number can't be looked at, so the bar stays while the game keeps it secret.
    if f.res then f:SetAlpha(((readable(max) and max <= 0) or (readable(v) and v <= 0)) and 0 or 1) end
    if f.n == 1 then
        f.segs[1]:SetMinMaxValues(0, max)
        f.segs[1]:SetValue(v)
        if f.over and f.over:IsShown() then fillOverlay(f, max) end
        if f.text:IsShown() and not pcall(setText, f.text, v) then f.text:SetText("") end
        if f.texts and not f.res then ns.fillTexts(f, v, max) end
    else
        for i = 1, f.n do f.segs[i]:SetValue(v) end
    end
end

------------------------------------------------------------------------------------------
-- Health, power and enemy health numbers: percent, current, current / max -- any of them,
-- each in its own spot, size and color. In a fight the game may keep the numbers secret: they
-- still draw (the game formats them), and a percent comes from the game's own percent call.
------------------------------------------------------------------------------------------
ns.TEXT_BARS = { health = true, power = true, enemyhealth = true }
ns.TEXT_KINDS = { "percent", "current", "currentmax" }

function ns.layoutTexts(f, c, n)
    f.texts = f.texts or {}
    local flags = c.outline and "OUTLINE" or ""
    for _, k in ipairs(ns.TEXT_KINDS) do
        local o, t = c.texts[k], f.texts[k]
        if not t then
            t = f.segs[1]:CreateFontString(nil, "OVERLAY")
            t:SetWordWrap(false)
            f.texts[k] = t
        end
        t:SetShown((c.text and o.show and n == 1) and true or false)
        if not t:SetFont(c.font, o.size, flags) then t:SetFont(FONTS[1][2], o.size, flags) end
        t:SetTextColor(unpack(o.color))
        t:ClearAllPoints()
        t:SetPoint(o.anchor, f.segs[1], o.anchor, o.x, o.y)
        t:SetJustifyH(o.anchor)
    end
end

ns.TEXT_FORMAT = {
    current = function(t, v) t:SetText(AbbreviateNumbers(v)) end,
    currentmax = function(t, v, max)
        local now = AbbreviateNumbers(v)
        if not pcall(function() t:SetText(now .. " / " .. AbbreviateNumbers(max)) end) then t:SetText(now) end
    end,
    percent = function(t, v, max, f)
        if readable(v) and readable(max) then
            t:SetText(max > 0 and math.floor(v / max * 100 + 0.5) .. "%" or "")
            return
        end
        local unit, curve = f.unit or "player", CurveConstants.ScaleTo100
        local p = f.key == "power" and UnitPowerPercent(unit, UnitPowerType(unit), true, curve)
            or UnitHealthPercent(unit, true, curve)
        t:SetText(string.format("%.0f%%", p))
    end,
}

function ns.fillTexts(f, v, max)
    for k, t in pairs(f.texts) do
        if t:IsShown() and not pcall(ns.TEXT_FORMAT[k], t, v, max, f) then t:SetText("") end
    end
end

function ns.resValue(unit)
    if not UnitExists(unit) then return 1, 1 end -- previewing: a full bar
    return UnitPower(unit), UnitPowerMax(unit)
end

-- The resource bar's settings: its own size, text switch and border, over enemy health's look.
function ns.resConf(c)
    return setmetatable({ height = c.resHeight, colorMode = "power", text = c.text and not c.resHideText,
        borderSize = c.resBorderSize, borderMode = c.resBorderMode, borderColor = c.resBorderColor,
        radius = c.resRadius }, { __index = c })
end

-- The resource bar inside enemy health, drawn over it: a share of its width, placed from its
-- bottom center.
function ns.layoutRes(f)
    local r, c = f.resFrame, db[f.mode].bars.enemyhealth
    r:SetShown(c.resource and true or false)
    if not c.resource then return end
    r:SetFrameLevel(f:GetFrameLevel() + 5)
    layoutBar(r, 1, math.max(1, math.floor(f.width * c.resWidth / 100 + 0.5)), ns.resConf(c))
    ns.fill(r)
    r:ClearAllPoints()
    r:SetPoint("BOTTOM", f, "BOTTOM", c.resX, c.resY)
end

-- Level and name, inset in enemy health. The level takes the color the game gives it (grey: no
-- experience, red: far above you), "+" for an elite, "??" for a skull. Without a target (placing
-- the bars) it shows your own level and "Target".
function ns.levelColor(level)
    local ok, c = pcall(GetCreatureDifficultyColor or GetQuestDifficultyColor, level)
    if ok and type(c) == "table" then return c.r, c.g, c.b end
    return 1, 1, 1
end

-- the level beside the name: its point, the name box's point, which way its padding pushes
ns.TAG_SIDES = { left = { "RIGHT", "LEFT", -1, 0 }, right = { "LEFT", "RIGHT", 1, 0 },
    top = { "BOTTOM", "TOP", 0, 1 }, bottom = { "TOP", "BOTTOM", 0, -1 } }

function ns.layoutTag(f)
    local c = db[f.mode].bars[f.key]
    local unit = UnitExists(f.unit) and f.unit
    local flags = c.tagOutline and "OUTLINE" or ""
    -- the level and the name: one font string each, in its own spot, on a frame that wraps it
    -- (padding all round) and wears its background
    for _, key in ipairs({ "tag_name", "tag_level" }) do
        if not f[key] then
            local box = CreateFrame("Frame", nil, f)
            local t = box:CreateFontString(nil, "OVERLAY")
            t:SetWordWrap(false)
            t.box, t.bg, t.mask = box, box:CreateTexture(nil, "BACKGROUND"), box:CreateMaskTexture()
            t.bg:SetAllPoints()
            t.mask:SetAllPoints(t.bg)
            f[key] = t
        end
    end
    -- The level beside the name, on the side the name starts from (left of a name on the left,
    -- right of one on the right): the level takes the name's spot and the name moves over.
    -- drinking: the name's place says so, flashing, even with the name itself turned off
    local drinking = (c.drinking.show and unit and ns.drinking(unit)) and true or false
    local nameOn = c.tagName or drinking
    local side = nameOn and ns.TAG_SIDES[c.tagAttach]
    local leads = side and c.tagLevel and ((c.tagAttach == "left" and c.nameAnchor == "LEFT")
        or (c.tagAttach == "right" and c.nameAnchor == "RIGHT"))
    for _, which in ipairs({ "name", "level" }) do
        local lvl = which == "level"
        local t = f["tag_" .. which]
        local on = (lvl and c.tagLevel or not lvl and nameOn) and true or false
        t:SetShown(on)
        t.box:SetShown(on)
        local flash = on and not lvl and drinking
        t.box:SetScript("OnUpdate", flash and function(self) self:SetAlpha(0.55 + 0.45 * math.cos(GetTime() * 6)) end or nil)
        if not flash then t.box:SetAlpha(1) end
        if on then
            if not t:SetFont(c.tagFont, c.tagSize, flags) then t:SetFont(FONTS[1][2], c.tagSize, flags) end
            local point, x, y, bg = c.tagAnchor, c.tagX, c.tagY, c.tagBg
            if not lvl then point, x, y, bg = c.nameAnchor, c.nameX, c.nameY, c.nameBg end
            t.box:SetFrameLevel(f:GetFrameLevel() + 7) -- over the resource bar
            t:ClearAllPoints()
            if leads and lvl then -- in the name's spot
                point = c.nameAnchor
                t:SetPoint(point, f, point, c.nameX, c.nameY)
            elseif leads then -- the name after the level, as far from it as the level would be
                t:SetPoint(side[2], f.tag_level.box, side[1], -c.tagX - side[3] * bg.pad, -c.tagY - side[4] * bg.pad)
            elseif lvl and side then -- next to the name's box, its own padding clear of it
                t:SetPoint(side[1], f.tag_name.box, side[2], x + side[3] * bg.pad, y + side[4] * bg.pad)
            else
                t:SetPoint(point, f, point, x, y)
            end
            t:SetJustifyH(point)
            if lvl then
                local level = unit and (UnitEffectiveLevel or UnitLevel)(unit) or UnitLevel("player")
                local kind = unit and UnitClassification and UnitClassification(unit)
                if readable(level) then
                    local r, g, b = 1, 0.1, 0.1
                    if level > 0 then r, g, b = ns.levelColor(level) end
                    t:SetTextColor(r, g, b, 1)
                    t:SetText(level <= 0 and "??" or level .. ((kind == "elite" or kind == "rareelite") and "+" or ""))
                else
                    t:SetText("")
                end
            else
                if drinking then
                    t:SetTextColor(unpack(c.drinking.color))
                    t:SetText("Drinking!")
                else
                    t:SetTextColor(unpack(c.tagNameColor))
                    pcall(t.SetText, t, unit and UnitName(unit) or "Target") -- a secret name still draws
                end
            end
            -- as wide as its text, up to the bar's width (then "..."); a secret name's width
            -- can't be read, so that one is never cut
            t:SetWidth(0)
            local w, most = t:GetStringWidth(), math.max(1, f.width - 2 * math.abs(x))
            if readable(w) and w > most then t:SetWidth(most) end
            t.box:ClearAllPoints()
            t.box:SetPoint("TOPLEFT", t, "TOPLEFT", -bg.pad, bg.pad)
            t.box:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", bg.pad, -bg.pad)
            t.bg:SetShown(bg.show and true or false)
            t.bg:SetColorTexture(unpack(bg.color))
            local h = c.tagSize + 2 * bg.pad -- the box's height, near enough, for the radius cap
            round(t.bg, t.mask, bg.radius == "pill" and math.huge or bg.radius, h * 2, h)
        end
    end
end

------------------------------------------------------------------------------------------
-- Buffs and debuffs on the enemy health bar: what Blizzard's target frame shows. Every buff;
-- on an enemy only your own debuffs (on a friend, and on clients before Dragonflight, all of
-- them). Nothing is compared: what the game hands over goes straight to the icon, secret or not.
------------------------------------------------------------------------------------------
-- Where a group starts: a corner of what it hangs on, and which way is away from it (x, y).
-- grow: the way each next icon goes. wrap: the way a new line goes (across grow); "auto": away
-- from what it hangs on -- or, when the icons already grow away, along its edge, inward.
ns.AURA_SPOTS = {
    topleft = { "TOPLEFT", 0, 1 }, topright = { "TOPRIGHT", 0, 1 },
    bottomleft = { "BOTTOMLEFT", 0, -1 }, bottomright = { "BOTTOMRIGHT", 0, -1 },
    righttop = { "TOPRIGHT", 1, 0 }, lefttop = { "TOPLEFT", -1, 0 },
}
ns.AURA_GROW = { right = { 1, 0 }, left = { -1, 0 }, up = { 0, 1 }, down = { 0, -1 } }
-- the old one-in-all choices, as a start corner and a direction
ns.AURA_OLD_SPOTS = { above_right = { "topleft", "right" }, above_left = { "topright", "left" },
    below_right = { "bottomleft", "right" }, below_left = { "bottomright", "left" },
    right = { "righttop", "right" }, left = { "lefttop", "left" } }

-- The group's own corner (where its first icon sits), its grow and new-line directions, its spot
function ns.auraDirs(o)
    local old = ns.AURA_OLD_SPOTS[o.spot]
    if old then o.spot, o.grow = old[1], old[2] end
    local sp, g = ns.AURA_SPOTS[o.spot] or ns.AURA_SPOTS.topleft, ns.AURA_GROW[o.grow] or ns.AURA_GROW.right
    local w, wd = { sp[2], sp[3] }, ns.AURA_GROW[o.wrap or ""]
    if wd and wd[1] * g[1] + wd[2] * g[2] == 0 then -- new lines the way asked (across the growing)
        w = { wd[1], wd[2] }
    elseif g[1] * sp[2] + g[2] * sp[3] ~= 0 then -- growing straight away (or back): new lines go along
        w = sp[3] ~= 0 and { sp[1]:find("LEFT") and 1 or -1, 0 } or { 0, -1 }
    end
    local hx, vy = g[1] ~= 0 and g[1] or w[1], g[2] ~= 0 and g[2] or w[2]
    return (vy > 0 and "BOTTOM" or "TOP") .. (hx > 0 and "LEFT" or "RIGHT"), g, w, sp
end

function ns.debuffFilter(unit)
    if unit == "player" or select(4, GetBuildInfo()) < 100000 then return "HARMFUL" end
    local ok, enemy = pcall(function() return UnitCanAttack("player", unit) and true or false end)
    return (ok and enemy) and "HARMFUL|PLAYER" or "HARMFUL"
end

-- Up to max auras, or nil when the game refuses to say (the icons then stay as they are).
function ns.auraList(unit, filter, max)
    local out = {}
    for i = 1, 40 do
        if #out >= max then break end
        local a
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
            if not ok then return nil end
            a = d
        elseif UnitAura then -- older clients: plain values
            local name, icon, count, _, duration, expires = UnitAura(unit, i, filter)
            a = name and { name = name, icon = icon, applications = count, duration = duration,
                expirationTime = expires }
        end
        if type(a) ~= "table" then break end
        out[#out + 1] = a
    end
    return out
end

-- Stand-ins while the options are open: as many as the group can hold, with running timers and
-- a stack count here and there, so size, zoom, timer text and the grid can all be judged.
ns.DUMMY_ICONS = {
    buffs = { "Spell_Holy_WordFortitude", "Spell_Nature_Regeneration", "Spell_Holy_MagicalSentry",
        "Spell_Holy_PowerWordShield" },
    debuffs = { "Spell_Shadow_ShadowWordPain", "Spell_Shadow_CurseOfSargeras", "Spell_Frost_FrostShock",
        "Ability_Warrior_Sunder" },
}
function ns.dummyAuras(k, max)
    local out, icons, now = {}, ns.DUMMY_ICONS[k], GetTime()
    for i = 1, max do
        out[i] = { icon = "Interface\\Icons\\" .. icons[(i - 1) % #icons + 1], duration = 60,
            expirationTime = now + 60 - i * 7 % 60, applications = i % 3 == 0 and 3 or nil }
    end
    return out
end

-- a = nil: a plain question mark
function ns.drawAura(b, unit, a)
    pcall(b.tex.SetTexture, b.tex, a and a.icon or 134400)
    b.count:SetText("")
    pcall(b.cd.Clear, b.cd)
    if not a then return end
    local id = a.auraInstanceID
    local timed = id and C_UnitAuras.GetAuraDuration and pcall(function()
        b.cd:SetCooldownFromDurationObject(C_UnitAuras.GetAuraDuration(unit, id))
    end)
    if not timed and readable(a.duration) and readable(a.expirationTime) and a.duration > 0 then
        b.cd:SetCooldown(a.expirationTime - a.duration, a.duration)
    end
    if id and C_UnitAuras.GetAuraApplicationDisplayCount then
        pcall(function() b.count:SetText(C_UnitAuras.GetAuraApplicationDisplayCount(unit, id, 2, 99)) end)
    elseif readable(a.applications) and a.applications > 1 then
        b.count:SetText(a.applications)
    end
end

-- The center line: across the middle of the bar (or of the bar with its pet / target of target).
-- A group sits on it with its bottom edge (above it), its center, or its top edge (below it),
-- gap away; on the side its start corner says. Alone there (the other group empty), centered.
ns.LINE_SIDES = { righttop = { "LEFT", "RIGHT" }, lefttop = { "RIGHT", "LEFT" }, topleft = { "LEFT", "LEFT" },
    bottomleft = { "LEFT", "LEFT" }, topright = { "RIGHT", "RIGHT" }, bottomright = { "RIGHT", "RIGHT" } }
function ns.linePlace(o, alone, gap)
    local side = ns.LINE_SIDES[o.spot] or ns.LINE_SIDES.righttop
    local edge, v, dy = alone and "center" or o.lineEdge, "", 0
    if edge == "top" then v, dy = "TOP", -gap elseif edge == "bottom" then v, dy = "BOTTOM", gap end
    return v .. side[1], side[2], o.x, o.y + dy
end

-- Each group lives in a box as big as its icons; the box hangs on the bar or on the other
-- group's box. Both on each other would hang in the air, so then buffs take the bar. One that
-- hangs on an empty group borrows that group's own anchor on the bar while it is empty: the
-- game draws nothing that hangs on a frame of no size (seen in game).
ns.AURA_BARS = { health = true, enemyhealth = true }
function ns.layoutAuras(f)
    local c = db[f.mode].bars[f.key]
    local unit = f.key == "health" and "player" or (UnitExists(f.unit) and f.unit)
    f.auraIcons = f.auraIcons or { buffs = {}, debuffs = {} }
    f.auraBoxes = f.auraBoxes or { buffs = CreateFrame("Frame", nil, f), debuffs = CreateFrame("Frame", nil, f) }
    -- with target of target hung on enemy health, or your pet on your health, "the bar" is the
    -- two together (a pet on the left starts the block)
    local host, other = f, nil
    if f.mode == "regular" and f.key == "enemyhealth" and ns.totPlaced() then other = frames.tothealth end
    if f.mode == "regular" and f.key == "health" and ns.petPlaced() then other = frames.pethealth end
    if other then
        local first = (other == frames.pethealth and db.regular.bars.pethealth.anchor == "left") and other or f
        f.span = f.span or CreateFrame("Frame", nil, f)
        f.span:ClearAllPoints()
        f.span:SetPoint("TOPLEFT", first, "TOPLEFT")
        f.span:SetPoint("BOTTOMRIGHT", first == f and other or f, "BOTTOMRIGHT")
        host = f.span
    end
    for _, k in ipairs({ "buffs", "debuffs" }) do
        local o, icons, box = c[k], f.auraIcons[k], f.auraBoxes[k]
        local corner, g, w = ns.auraDirs(o)
        local step = o.size + c.auraGap
        local across = g[1] ~= 0 -- growing sideways: a line is a row; up or down: a column
        local per = across and o.cols or o.rows
        local max = math.min(o.max, o.cols * o.rows)
        local list = {}
        if o.show and ns.previewing() then -- the options are open: a full grid to tune it by
            list = ns.dummyAuras(k, max)
        elseif o.show and unit then
            list = ns.auraList(unit, k == "buffs" and "HELPFUL" or ns.debuffFilter(unit), max)
        end
        if list then -- nil: the game refused, the icons stay as they are
            local n = math.min(#list, max)
            local file = ns.ICON_MASKS[o.radius]
            for i = 1, math.max(n, #icons) do
                local b = icons[i]
                if not b and i <= n then
                    b = CreateFrame("Frame", nil, box)
                    b.tex = b:CreateTexture(nil, "ARTWORK")
                    b.tex:SetAllPoints()
                    b.mask = b:CreateMaskTexture()
                    b.mask:SetAllPoints(b.tex)
                    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
                    b.cd:SetAllPoints()
                    b.cd:SetReverse(true)
                    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
                    b.count:SetPoint("BOTTOMRIGHT", -1, 1)
                    icons[i] = b
                end
                if b then
                    b:SetShown(i <= n)
                    if i <= n then
                        local a, l = (i - 1) % per, math.floor((i - 1) / per) -- place in its line, which line
                        b:SetSize(o.size, o.size)
                        b:SetFrameLevel(f:GetFrameLevel() + 6)
                        b:ClearAllPoints()
                        b:SetPoint(corner, box, corner, (g[1] * a + w[1] * l) * step, (g[2] * a + w[2] * l) * step)
                        -- zoom: the share cut from each side of the picture (8: just its own border)
                        local z = (o.zoom or 8) / 100
                        ns.iconCorners(b.tex, b.mask, o.radius, { z, 1 - z, z, 1 - z })
                        -- the swipe takes the icon's shape too
                        b.cd:SetSwipeTexture(file and "Interface\\AddOns\\WolfpackAddon\\Media\\Icon\\"
                            .. file .. ".tga" or "Interface\\Buttons\\WHITE8X8")
                        b.cd:SetSwipeColor(0, 0, 0, 0.7)
                        b.cd:SetHideCountdownNumbers(o.hideTimer and true or false)
                        ns.drawAura(b, unit, list[i] or nil)
                    end
                end
            end
            local along, lines = math.min(n, per) * step - c.auraGap, math.ceil(n / per) * step - c.auraGap
            box:SetSize(n > 0 and (across and along or lines) or 1, n > 0 and (across and lines or along) or 1)
            box.n = n
        end
    end
    for _, k in ipairs({ "buffs", "debuffs" }) do -- now that both know how many they hold
        local o, box = c[k], f.auraBoxes[k]
        local other = k == "buffs" and "debuffs" or "buffs"
        local corner, _, _, sp = ns.auraDirs(o)
        local toOther = o.anchorTo == "other" and not (k == "buffs" and c.debuffs.anchorTo == "other")
        local into = f.auraBoxes[other]
        local alone = (into.n or 0) == 0
        box:ClearAllPoints()
        if o.anchorTo == "line" then -- on the center line; alone on it, centered
            local gp, hp, x, y = ns.linePlace(o, alone, c.auraLineGap or 0)
            box:SetPoint(gp, host, hp, x, y)
        elseif toOther and alone and c[other].anchorTo == "line" then -- the empty one's place on the line
            local gp, hp, x, y = ns.linePlace(c[other], true, 0)
            box:SetPoint(gp, host, hp, x, y)
        elseif toOther and alone then -- the empty group's anchor (it hangs on the bar)
            local _, _, _, osp = ns.auraDirs(c[other])
            box:SetPoint(corner, host, osp[1], c[other].x, c[other].y)
        else
            local gap = toOther and c.auraGroupGap or 0 -- away from the group it hangs on
            box:SetPoint(corner, toOther and into or host, sp[1], o.x + sp[2] * gap, o.y + sp[3] * gap)
        end
    end
end

------------------------------------------------------------------------------------------
-- Small icons on the bars: PvP flag and drinking on enemy health, status (combat / rested)
-- and your PvP flag on your health
------------------------------------------------------------------------------------------
-- Combat icon art: an atlas or a file (with a crop). Rested: the Zzz from the same state icon.
local COMBAT_ICONS = {
    { "Player frame swords", "atlas" },
    { "Classic swords", "classic" },
    { "Dual Wield icon", "dualwield" },
    { "Battle Stance icon", "battle" },
}
local COMBAT_ART = {
    atlas = { atlas = "UI-HUD-UnitFrame-Player-CombatIcon" },
    classic = { file = 130936, coords = { 0.5, 1, 0, 0.49 } },     -- Interface/CHARACTERFRAME/UI-StateIcon
    dualwield = { file = 132147, coords = { 0.08, 0.92, 0.08, 0.92 } }, -- Interface/ICONS/Ability_DualWield
    battle = { file = 132349, coords = { 0.08, 0.92, 0.08, 0.92 } }, -- Interface/ICONS/Ability_Warrior_OffensiveStance
}
local function setCombatArt(t, style)
    local a = COMBAT_ART[style] or COMBAT_ART.atlas
    if a.atlas then
        t:SetAtlas(a.atlas)
    else
        t:SetTexture(a.file)
        t:SetTexCoord(unpack(a.coords))
    end
end

local REST_ART = { file = 130936, coords = { 0, 0.5, 0, 0.421875 } } -- Interface/CHARACTERFRAME/UI-StateIcon
ns.BADGES = { health = { "statusIcon", "pvpIcon" }, enemyhealth = { "pvpIcon" } }
-- the badge's own point that meets a point of the name / level box, so it sits outside on that side
ns.OPPOSITE = { TOPLEFT = "BOTTOMRIGHT", TOP = "BOTTOM", TOPRIGHT = "BOTTOMLEFT", LEFT = "RIGHT", CENTER = "CENTER",
    RIGHT = "LEFT", BOTTOMLEFT = "TOPRIGHT", BOTTOM = "TOP", BOTTOMRIGHT = "TOPLEFT" }
-- looks for the PvP icon: a file (or one per faction, FFA for free-for-all) and its crop
ns.PVP_STYLES = {
    faction = { file = "Interface\\TargetingFrame\\UI-PVP-%s", coords = { 0, 0.62, 0, 0.62 } },
    banner = { Alliance = "Interface\\Icons\\INV_BannerPVP_02", Horde = "Interface\\Icons\\INV_BannerPVP_01",
        FFA = "Interface\\Icons\\INV_BannerPVP_01", coords = { 0.08, 0.92, 0.08, 0.92 } },
    swords = { file = "Interface\\WorldStateFrame\\CombatSwords", coords = { 0, 0.5, 0, 0.5 } },
    skull = { file = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", coords = { 0, 1, 0, 1 } },
}

-- "Alliance", "Horde" or "FFA" while the unit is flagged, else nil
function ns.pvpFlag(unit)
    local ok, ffa = pcall(UnitIsPVPFreeForAll, unit)
    if ok and readable(ffa) and ffa then return "FFA" end
    local ok2, on = pcall(UnitIsPVP, unit)
    if not (ok2 and readable(on) and on) then return end
    local faction = UnitFactionGroup(unit)
    return (faction == "Alliance" or faction == "Horde") and faction or "FFA"
end

-- Whether it is drinking: a buff called Drink, Food & Drink or Refreshment (or the game's own
-- name for Drink in this language). A name the game keeps secret can't be told: not drinking.
function ns.drinking(unit)
    local names = { drink = true, ["food & drink"] = true, refreshment = true }
    local ok, own = pcall(function() return C_Spell and C_Spell.GetSpellName(430) or GetSpellInfo(430) end)
    if ok and type(own) == "string" then names[own:lower()] = true end
    for _, a in ipairs(ns.auraList(unit, "HELPFUL", 40) or {}) do
        if readable(a.name) and type(a.name) == "string" and names[a.name:lower()] then return true end
    end
    return false
end

-- A text one letter per font string, side by side, so each can fade on its own: a wave of
-- fading in and out runs along it while o.restWave is on. Up to 16 letters (UTF-8 aware).
function ns.waveLetters(b)
    local t = GetTime()
    for i = 1, b.waveN do b.letters[i]:SetAlpha(0.15 + 0.85 * (0.5 + 0.5 * math.sin(t * 3 - i * 0.7))) end
end

function ns.layoutLetters(b, str, c, o)
    b.letters = b.letters or {}
    local n, x = 0, 0
    if str then
        local flags = c.outline and "OUTLINE" or ""
        for ch in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            if n == 16 then break end
            n = n + 1
            local l = b.letters[n] or b:CreateFontString(nil, "OVERLAY")
            b.letters[n] = l
            if not l:SetFont(c.font, c.fontSize, flags) then l:SetFont(FONTS[1][2], c.fontSize, flags) end
            l:SetTextColor(unpack(o.restColor))
            l:SetText(ch)
            l:ClearAllPoints()
            l:SetPoint("LEFT", b, "LEFT", x, 0)
            l:SetAlpha(1)
            l:Show()
            local w = l:GetStringWidth()
            x = x + (readable(w) and w or c.fontSize * 0.6)
        end
        b:SetSize(math.max(1, x), c.fontSize)
    end
    for i = n + 1, #b.letters do b.letters[i]:Hide() end
    b.waveN = n
    b:SetScript("OnUpdate", (str and n > 0 and o.restWave) and ns.waveLetters or nil)
end

function ns.layoutBadges(f)
    local c = db[f.mode].bars[f.key]
    local unit = f.key == "health" and "player" or (UnitExists(f.unit) and f.unit)
    local preview = ns.previewing()
    for _, k in ipairs(ns.BADGES[f.key]) do
        local o, b = c[k], f[k]
        if not b then
            b = CreateFrame("Frame", nil, f)
            b.tex = b:CreateTexture(nil, "OVERLAY")
            b.tex:SetAllPoints()
            b.text = b:CreateFontString(nil, "OVERLAY")
            b.text:SetPoint("CENTER")
            f[k] = b
        end
        local art, text, letters -- art: { file, coords } or a combat icon style; text: PvP; letters: resting
        if not o.show then
            art = nil
        elseif k == "pvpIcon" then
            local flag = unit and ns.pvpFlag(unit) or (preview and (UnitFactionGroup("player") or "FFA"))
            local st = ns.PVP_STYLES[o.style] or ns.PVP_STYLES.faction
            if flag and o.style == "text" then
                text = o.text
            elseif flag then
                art = { file = st[flag] or (st.file and st.file:format(flag)) or st.Horde, coords = st.coords }
            end
        elseif ns.inCombat then
            art = o.style
        elseif o.rested and IsResting() then
            if o.restStyle == "text" then letters = o.restText or "" else art = REST_ART end
        elseif preview then -- status: shown while placing it, for placing it
            art = o.style
        end
        b:SetShown(art ~= nil or text ~= nil or letters ~= nil)
        b.tex:SetShown(art ~= nil)
        b.text:SetShown(text ~= nil)
        ns.layoutLetters(b, letters, c, o)
        if art or text or letters then
            if letters then
                -- sized by layoutLetters
            elseif text then -- the font and size of the name on enemy health, of the bar's text on yours
                local font, size, outline = c.font, c.fontSize, c.outline
                if f.key == "enemyhealth" then font, size, outline = c.tagFont, c.tagSize, c.tagOutline end
                local flags = outline and "OUTLINE" or ""
                if not b.text:SetFont(font, size, flags) then b.text:SetFont(FONTS[1][2], size, flags) end
                b.text:SetTextColor(unpack(o.textColor))
                b.text:SetText(text)
                local w = b.text:GetStringWidth()
                b:SetSize(readable(w) and math.max(1, w) or size, size)
            else
                if type(art) == "string" then setCombatArt(b.tex, art)
                else
                    b.tex:SetTexture(art.file)
                    b.tex:SetTexCoord(unpack(art.coords))
                end
                b:SetSize(o.size, o.size)
            end
            b:SetFrameLevel(f:GetFrameLevel() + 8)
            b:ClearAllPoints()
            -- on the bar, centered on its point; or outside the name / level, on that side of it
            local host = (o.anchorTo == "name" and f.tag_name) or (o.anchorTo == "level" and f.tag_level)
            if host and host:IsShown() then
                b:SetPoint(ns.OPPOSITE[o.point] or "CENTER", host.box, o.point, o.x, o.y)
            else
                b:SetPoint("CENTER", f, o.point, o.x, o.y)
            end
        end
    end
end

------------------------------------------------------------------------------------------
-- Target of target, hung on enemy health (your Combat Display only; on nameplates it stacks)
------------------------------------------------------------------------------------------
function ns.totPlaced()
    local t = db.regular.bars.tothealth
    return (t.show and t.anchor ~= "stack" and (UnitExists("targettarget") or ns.previewing())) and true or false
end
function ns.totBelow() return ns.totPlaced() and db.regular.bars.tothealth.anchor == "below" end
function ns.totShare() return db.regular.bars.tothealth.height + db.regular.gap end -- what it takes below

-- your pet, hung on your health
function ns.petPlaced()
    local c = db.regular.bars.pethealth
    return (c.show and c.anchor ~= "stack" and (UnitExists("pet") or ns.previewing())) and true or false
end
function ns.petBelow() return ns.petPlaced() and db.regular.bars.pethealth.anchor == "below" end

-- Below your health it is part of the stack: placed right under it, as wide as it is; returns
-- the room it takes.
function ns.petUnder(hf)
    if not ns.petBelow() then return 0 end
    local c, pf, gap = db.regular.bars.pethealth, frames.pethealth, db.regular.gap
    pf:Show()
    layoutBar(pf, 1, hf.width)
    pf:ClearAllPoints()
    pf:SetPoint("TOPLEFT", hf, "BOTTOMLEFT", 0, -gap)
    ns.fill(pf)
    return gap + c.height
end

function ns.placePet()
    local c, pf, hf, gap = db.regular.bars.pethealth, frames.pethealth, frames.health, db.regular.gap
    if c.anchor == "stack" then return end
    local on = (ns.petPlaced() and hf:IsShown()) and true or false
    pf:SetShown(on)
    if not on or c.anchor == "below" then return end -- below: the stack placed it
    layoutBar(pf, 1, c.width, { height = hf:GetHeight() }) -- your health's height, its own width
    pf:ClearAllPoints()
    if c.anchor == "left" then
        pf:SetPoint("TOPRIGHT", hf, "TOPLEFT", -gap, 0)
    else
        pf:SetPoint("TOPLEFT", hf, "TOPRIGHT", gap, 0)
    end
    ns.fill(pf)
end

function ns.placeToT()
    local c, tf, ef = db.regular.bars.tothealth, frames.tothealth, frames.enemyhealth
    if c.anchor == "stack" then return end
    local on = (ns.totPlaced() and ef:IsShown()) and true or false
    tf:SetShown(on)
    if not on then return end
    local gap = db.regular.gap
    tf:ClearAllPoints()
    if c.anchor == "below" then -- enemy health's width, its own height
        layoutBar(tf, 1, ef.width)
        tf:SetPoint("TOPLEFT", ef, "BOTTOMLEFT", 0, -gap)
    else -- enemy health's height, its own width
        layoutBar(tf, 1, c.width, { height = ef:GetHeight() })
        tf:SetPoint("TOPLEFT", ef, "TOPRIGHT", gap, 0)
    end
    ns.fill(tf)
    ns.layoutTag(tf)
end

local function targetPlate()
    local ok, p = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    if ok and p and not (p.IsForbidden and p:IsForbidden()) then return p end
end

------------------------------------------------------------------------------------------
-- Quest mobs: a sword on nameplates of mobs you still need to kill, a bag on mobs that drop
-- an item you still need. Read from the unit tooltip's quest lines; the quest log says which
-- objective is an item.
------------------------------------------------------------------------------------------
local QUEST_ICONS = {
    kill = {
        { "Sword cursor", 131013 },     -- Interface/CURSOR/Attack
        { "Crosshair sword", 4675619 }, -- Interface/CURSOR/Crosshair/Attack
        { "Sword", 135274 },            -- Interface/ICONS/INV_Sword_04
        { "Crossed swords", 132147 },   -- Interface/ICONS/Ability_DualWield
    },
    loot = {
        { "Loot cursor", 131023 },      -- Interface/CURSOR/LootAll
        { "Crosshair loot", 4675637 },  -- Interface/CURSOR/Crosshair/LootAll
        { "Bag", 133633 },              -- Interface/ICONS/INV_Misc_Bag_08
        { "Coin bag", 901746 },         -- Interface/ICONS/INV_Misc_CoinBag_Special
    },
}

local QUEST_ORDER = { "kill", "loot" } -- left to right

local LINE = Enum.TooltipDataLineType
local objectiveInfo = {} -- objective text without numbers -> { type, left } from your own quest log
local playerName

-- "Boar Flank: 2/6" and "2/6 Boar Flank" both become "BoarFlank".
local function bareText(text) return (text:gsub("[%d%p%s]", "")) end

-- The modern clients list quests in C_QuestLog; Anniversary (2.5) and Classic Era (1.15) still
-- have the old global calls, whose objectives are text like "Boar Flank: 2/6".
local function scanQuestLog()
    wipe(objectiveInfo)
    local Q = C_QuestLog or {}
    local count = Q.GetNumQuestLogEntries or GetNumQuestLogEntries
    if not count then return end
    for i = 1, count() or 0 do
        local header, questID
        if Q.GetInfo then
            local info = Q.GetInfo(i)
            header, questID = not info or info.isHeader, info and info.questID
        else
            local _
            _, _, _, header, _, _, _, questID = GetQuestLogTitle(i)
        end
        if not header then
            local objectives = Q.GetQuestObjectives and questID and Q.GetQuestObjectives(questID)
            if not objectives and GetNumQuestLeaderBoards then
                objectives = {}
                for j = 1, GetNumQuestLeaderBoards(i) or 0 do
                    local text, kind, finished = GetQuestLogLeaderBoard(j, i)
                    local have, need = (text or ""):match("(%d+)%s*/%s*(%d+)")
                    objectives[j] = { text = text, type = kind, finished = finished,
                        numFulfilled = tonumber(have), numRequired = tonumber(need) }
                end
            end
            for _, o in ipairs(objectives or {}) do
                if o.text and not o.finished then
                    objectiveInfo[bareText(o.text)] = { type = o.type,
                        left = math.max((o.numRequired or 0) - (o.numFulfilled or 0), 0) }
                end
            end
        end
    end
end

-- kill, loot for a unit: "mine", "party" (only groupmates still need it) or nil, plus how many
-- are still needed (from the "3/10" in the tooltip line, so groupmates' numbers work too). Open
-- objectives only. In a group the tooltip names whose objective follows (QuestPlayer lines); where
-- it doesn't, the objective counts as yours. ponytail: objective types come from your own quest
-- log, so a groupmate's item objective for a quest you don't have shows as a kill.
local function questKinds(unit)
    -- the icons are read off the unit's tooltip data, which older clients don't hand to addons
    if not (C_TooltipInfo and LINE and C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest) then
        return nil, nil, {}
    end
    local related = C_QuestLog.UnitIsRelatedToActiveQuest(unit)
    if not related and not IsInGroup() then return nil, nil, {} end -- solo: skip the tooltip
    local data = C_TooltipInfo.GetUnit(unit)
    local mine, party, anyObjective, own = {}, {}, false, true
    local left = {}
    for _, line in ipairs(data and data.lines or {}) do
        if line.type == LINE.QuestTitle then
            own = true
        elseif line.type == LINE.QuestPlayer then
            own = line.leftText == playerName
        elseif line.type == LINE.QuestObjective then
            anyObjective = true
            if not line.completed then
                local text = line.leftText or ""
                local info = objectiveInfo[bareText(text)]
                local kind = (info and info.type == "item") and "loot" or "kill"
                -- your own quest log wins over the tooltip's player labels: if you still need it,
                -- the icon is yours (in a group the tooltip doesn't always name you)
                local isMine = own or info ~= nil
                if isMine then mine[kind] = true else party[kind] = true end
                local remaining
                if isMine and info then
                    remaining = info.left
                else
                    local have, need = text:match("(%d+)%s*/%s*(%d+)")
                    if have then remaining = need - have end
                end
                if remaining and remaining > 0 then -- several quests on one mob: the biggest count
                    left[kind] = math.max(left[kind] or 0, remaining)
                end
            end
        end
    end
    if not anyObjective and related then mine.kill = true end -- quest mob, but no objective named
    return mine.kill and "mine" or party.kill and "party" or nil,
        mine.loot and "mine" or party.loot and "party" or nil, left
end

-- Nameplates are recycled, so each plate keeps one icon holder; plateUnits maps the units
-- currently on screen to their holder.
local questHolders, plateUnits = {}, {}
ns.plateUnits = plateUnits

-- The row's box always has room for every enabled icon type; the icons a mob needs fill it from
-- the left, so a lone icon sits at the box's left edge.
local function styleQuest(h)
    local q, w, ht = db.quest, 0, 0
    for _, kind in ipairs(QUEST_ORDER) do
        local c = q[kind]
        if c.show then
            w = w + (w > 0 and q.spacing or 0) + c.size
            ht = math.max(ht, c.size)
        end
    end
    h.box:SetSize(math.max(w, 1), math.max(ht, 1))
    h.box:ClearAllPoints()
    h.box:SetPoint("TOPRIGHT", h, "TOPRIGHT", q.x, q.y)
    local x = 0
    for _, kind in ipairs(QUEST_ORDER) do
        local c, t = q[kind], h[kind]
        local on = (h.want[kind] and c.show) and true or false
        t:SetTexture(c.icon)
        t:SetDesaturated(h.want[kind] == "party") -- groupmates need it, you don't: grayscale
        t:SetSize(c.size, c.size)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", h.box, "TOPLEFT", x, 0)
        t:SetShown(on)
        local badge, count = h.badge[kind], h.left[kind]
        local showCount = (on and c.count and count and count > 0) and true or false
        badge.text:SetShown(showCount)
        badge.bg:SetShown(showCount)
        if showCount then
            badge.text:SetText(count)
            badge.bg:SetSize(badge.text:GetStringWidth() + 4, badge.text:GetStringHeight() + 2)
        end
        if on then x = x + c.size + q.spacing end
    end
end

local function evalQuest(unit)
    local h = plateUnits[unit]
    if not h then return end
    local ok, kill, loot, left = pcall(questKinds, unit)
    if ok then -- secret mid-combat: keep what we had
        h.want.kill, h.want.loot = kill, loot
        h.left.kill, h.left.loot = left.kill, left.loot
    end
    styleQuest(h)
end

local function plateAdded(unit)
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate or plate:IsForbidden() then return end
    local h = questHolders[plate]
    if not h then
        h = CreateFrame("Frame", nil, plate)
        h:SetAllPoints()
        h:SetFrameLevel(plate:GetFrameLevel() + 10)
        h.box = CreateFrame("Frame", nil, h)
        h.kill, h.loot, h.want, h.left = h.box:CreateTexture(nil, "OVERLAY"), h.box:CreateTexture(nil, "OVERLAY"), {}, {}
        h.badge = {}
        for _, kind in ipairs(QUEST_ORDER) do -- small "how many left" plate above the icon
            local bg = h.box:CreateTexture(nil, "OVERLAY", nil, 1)
            bg:SetColorTexture(0, 0, 0, 0.8)
            local text = h.box:CreateFontString(nil, "OVERLAY", nil, 2)
            text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            text:SetPoint("BOTTOM", h[kind], "TOP", 0, 2)
            bg:SetPoint("CENTER", text)
            h.badge[kind] = { bg = bg, text = text }
        end
        questHolders[plate] = h
    end
    h.want.kill, h.want.loot = nil, nil
    h.left.kill, h.left.loot = nil, nil
    plateUnits[unit] = h
    evalQuest(unit)
end

local function plateRemoved(unit)
    local h = plateUnits[unit]
    if not h then return end
    h.want.kill, h.want.loot = nil, nil
    styleQuest(h)
    plateUnits[unit] = nil
end

local function questLogChanged()
    scanQuestLog()
    for unit in pairs(plateUnits) do evalQuest(unit) end
end

-- Lays out one stack: shown bars in order, touching with the gap. Each bar sits in its slot
-- plus its own x/y offset; offsets don't push the other bars around.
local function stack(container, set, L, on, swings)
    local w, h = 0, 0
    for _, key in ipairs(L.order) do
        local f, c = set[key], L.bars[key]
        local shown, n = BARS[key].state()
        shown = (on and shown and c.show) and true or false
        if key == "enemyhealth" and c.beside and L == db.regular then shown = false end -- Refresh places it
        -- hung on another bar (your Combat Display only): placed with that bar, or by Refresh
        local hung = L == db.regular and (key == "tothealth" or key == "pethealth") and c.anchor ~= "stack"
        if key == "swing" then -- one row per ticked weapon, sharing this bar's settings
            for i, kind in ipairs(SWING_TYPES) do
                local sf = swings[i]
                local rowShown = (shown and c[kind[1]] and (swingActive(kind[3]) or ns.previewing())) and true or false
                sf:SetShown(rowShown)
                if rowShown then
                    layoutBar(sf, 1)
                    ns.fill(sf)
                    if h > 0 then h = h + L.gap end
                    h = h + c.padTop
                    sf:ClearAllPoints()
                    sf:SetPoint("TOP", container, "TOP", c.x, c.y - h)
                    h = h + c.height + c.padBottom
                    w = math.max(w, c.width)
                end
            end
            shown = false
        end
        if hung then shown = false else f:SetShown(shown) end
        if shown then
            -- f.split: the player health bar shares its width with the enemy health bar
            -- target of target below enemy health: the two share enemy health's slot
            local over = key == "enemyhealth" and L == db.regular and ns.totBelow()
                and { height = math.max(2, c.height - ns.totShare()) } or nil
            layoutBar(f, n, f.split and (c.width - L.gap) / 2 or nil, over)
            ns.fill(f)
            if h > 0 then h = h + L.gap end
            h = h + c.padTop
            f:ClearAllPoints()
            if f.split then
                f:SetPoint("TOPLEFT", container, "TOP", c.x - c.width / 2, c.y - h)
            else
                f:SetPoint("TOP", container, "TOP", c.x, c.y - h)
            end
            if f.resFrame or key == "tothealth" then ns.layoutTag(f) end
            if f.resFrame then ns.layoutRes(f) end
            if ns.AURA_BARS[key] then ns.layoutAuras(f) end
            if ns.BADGES[key] then ns.layoutBadges(f) end
            h = h + c.height
            if key == "health" and L == db.regular then h = h + ns.petUnder(f) end -- your pet below it
            h = h + c.padBottom
            w = math.max(w, c.width)
        end
    end
    container:SetSize(h > 0 and w or 20, h > 0 and h or 10) -- keeps an empty stack grabbable while unlocked
end

------------------------------------------------------------------------------------------
-- Blizzard player frame: hide it, and/or give the bars its right-click menu. Both touch
-- protected frames, which can only change out of combat; PLAYER_REGEN_ENABLED catches up.
------------------------------------------------------------------------------------------
local hider = CreateFrame("Frame")
hider:Hide()
-- Blizzard unit frames hidden by parking them under `hider`: the option for each, and where it
-- was before (to give it back). Never touched unless asked.
ns.unitFrameHides = { { "PlayerFrame", "hidePlayerFrame" }, { "TargetFrame", "hideTargetFrame" } }
ns.unitFrameParents = {}
local castHidden, castParent, castHooked

-- Blizzard's player cast bar: parked under the hidden frame. Blizzard re-parents it itself when
-- the "lock to player frame" setting applies, so a secure hook parks it again and remembers where
-- Blizzard wanted it, for when the option goes off. No Blizzard fields or methods are touched.
local function syncCastbar()
    local bar = PlayerCastingBarFrame
    local hide = db.regular.hideBlizzCastbar and true or false
    if not bar or not (hide or castHidden) then return end
    if not castHooked then
        hooksecurefunc(bar, "SetParent", function(self, parent)
            if parent == hider then return end
            castParent = parent
            if castHidden and not InCombatLockdown() then self:SetParent(hider) end
        end)
        castHooked = true
    end
    if hide and not castHidden then castParent = bar:GetParent() end
    castHidden = hide
    local want = hide and hider or castParent
    if bar:GetParent() ~= want then bar:SetParent(want) end
end

local function syncProtected()
    if InCombatLockdown() then return end
    syncCastbar() -- may be attached to the (protected) player frame, so also out of combat only
    for _, u in ipairs(ns.unitFrameHides) do
        local frame, hide = _G[u[1]], db.regular[u[2]] and true or false
        local was = ns.unitFrameParents[u[1]]
        if frame and hide ~= (was ~= nil) then
            if hide then ns.unitFrameParents[u[1]] = frame:GetParent() end
            frame:SetParent(hide and hider or was)
            if not hide then ns.unitFrameParents[u[1]] = nil end
        end
    end
    ns.syncClickers()
end

-- Secure unit buttons over your health and power bars, clicking like Blizzard's player frame:
-- left targets you, right opens the menu. Their "unit" attribute is also what makes the game
-- treat you as @mouseover while the cursor is on them. ponytail: not children of the bars (that
-- would lock the bars' layout in combat), so their size and spot follow them out of combat only
-- -- read from where the stack put each bar, and where the group sits. With enemy health beside
-- yours, the health one covers only your half, whether there is a target yet or not.
-- The enemy health bar has one too (unit "target", right-click menu). The game's unit watch shows
-- it only while you have a target, in combat as well; ponytail: its spot is the bar's last one
-- out of combat, which is off only if the stack changes shape mid-fight.
-- Your pet and your target's target have one each too (right-click menu, unit watch). Hung on
-- another bar, theirs hangs on that bar's button (secure on secure, so that is allowed in combat).
ns.clickers = {}
local CLICKERS = { health = { "WolfpackAddonClicker", "player" }, power = { "WolfpackAddonClickerPower", "player" },
    enemyhealth = { "WolfpackAddonClickerTarget", "target" }, pethealth = { "WolfpackAddonClickerPet", "pet" },
    tothealth = { "WolfpackAddonClickerToT", "targettarget" } }
local HUNG_ON = { pethealth = "health", tothealth = "enemyhealth" }
function ns.syncClickers()
    local R = db.regular
    local eh = R.bars.enemyhealth
    local beside = eh.show and eh.beside
    local top = R.grow == "up" and R.y + anchor:GetHeight() or R.y -- the group's top edge
    local player = (R.playerMenu or R.playerTarget or R.playerMouseover) and true or false
    local want = { health = player, power = player, enemyhealth = R.targetMenu, pethealth = R.petMenu,
        tothealth = R.totMenu }
    local function hungWanted(key) return want[key] and R.bars[key].show and R.bars[key].anchor ~= "stack" end
    for _, key in ipairs({ "health", "power", "enemyhealth", "pethealth", "tothealth" }) do
        local b, f, mine = R.bars[key], frames[key], CLICKERS[key][2] == "player"
        local c = ns.clickers[key]
        -- also made for a bar whose pet / target of target hangs on it, to hang that one on
        local need = want[key] or (key == "health" and hungWanted("pethealth"))
            or (key == "enemyhealth" and hungWanted("tothealth"))
        if need and not c then
            c = CreateFrame("Button", CLICKERS[key][1], UIParent, "SecureUnitButtonTemplate")
            c:SetAttribute("unit", CLICKERS[key][2])
            c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            ns.clickers[key] = c
        end
        if c then
            c:SetAttribute("type1", mine and R.playerTarget and "target" or nil)
            c:SetAttribute("type2", (not mine or R.playerMenu) and "togglemenu" or nil)
            local host = HUNG_ON[key] and b.anchor ~= "stack" and ns.clickers[HUNG_ON[key]]
            local point, _, _, x, y = (key == "enemyhealth" and beside and frames.health or f):GetPoint(1)
            local placed = host or point ~= nil
            local on = want[key] and db.locked and placed -- unlocked: dragging wins
                and (mine and f:IsShown() or not mine and b.show)
            if mine then
                c:SetShown(on or false)
            elseif on then
                RegisterUnitWatch(c)
            else
                UnregisterUnitWatch(c)
                c:Hide()
            end
            if placed then
                local w, h = f:GetWidth(), b.height
                c:ClearAllPoints()
                if host then
                    c:SetFrameLevel(host:GetFrameLevel() + 1)
                    if b.anchor == "below" and key == "tothealth" then -- the bottom of enemy health's slot
                        w = host:GetWidth()
                        c:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT")
                    elseif b.anchor == "below" then -- your pet: under your health
                        w = host:GetWidth()
                        c:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, -R.gap)
                    else
                        w, h = b.width, host:GetHeight()
                        if b.anchor == "left" then
                            c:SetPoint("TOPRIGHT", host, "TOPLEFT", -R.gap, 0)
                        else
                            c:SetPoint("TOPLEFT", host, "TOPRIGHT", R.gap, 0)
                        end
                    end
                elseif beside and key ~= "power" then -- the two halves of your health bar's width
                    local hb = R.bars.health
                    w, h = (hb.width - R.gap) / 2, hb.height
                    -- enemy health beside you also spans a pet below your health
                    if key == "enemyhealth" and ns.petBelow() then h = h + R.bars.pethealth.height + R.gap end
                    local left = R.x + hb.x - hb.width / 2 + (key == "enemyhealth" and w + R.gap or 0)
                    c:SetPoint("TOPLEFT", UIParent, "CENTER", left, top + y)
                else
                    c:SetPoint(point, UIParent, "CENTER", R.x + x, top + y)
                end
                c:SetSize(w, h)
            end
        end
    end
end

-- Action bar gryphons (Forever: MainActionBar.EndCaps). Only their textures' alpha changes, so
-- Blizzard's Edit Mode code on those frames stays untouched. Left alone unless the option was on.
local gryphonsHidden
local function syncGryphons()
    local hide = db.other.hideGryphons and true or false
    local caps = MainActionBar and MainActionBar.EndCaps
    if not caps or hide == (gryphonsHidden or false) then return end
    for _, cap in ipairs({ caps.LeftEndCap, caps.RightEndCap }) do
        if cap and cap.Texture then cap.Texture:SetAlpha(hide and 0 or 1) end
    end
    gryphonsHidden = hide
end

local inCombat -- from PLAYER_REGEN_DISABLED / _ENABLED

-- Five-second rule: spending mana stops Spirit-based regen for five seconds. This spinner runs
-- for exactly that window. It's a cooldown swipe, so the animation happens in C and nothing about
-- it ever has to be read back.
local fsr = { classes = { DRUID = true, HUNTER = true, MAGE = true, PALADIN = true,
    PRIEST = true, SHAMAN = true, WARLOCK = true } }
fsr.frame = CreateFrame("Cooldown", nil, anchor, "CooldownFrameTemplate")
fsr.frame:SetHideCountdownNumbers(true)
fsr.frame:SetDrawEdge(false)
fsr.frame:SetDrawBling(false)
-- The swipe is masked to a ring texture, so it sweeps as a ring instead of a pie slice.
fsr.frame:SetSwipeTexture("Interface\\AddOns\\WolfpackAddon\\Media\\Ring")
fsr.frame:Hide()
ns.fsr = fsr

-- Spell costs are static data, but a pcall keeps a missing API (or a secret cost) from erroring:
-- when we can't tell, assume the cast cost mana.
function fsr.costsMana(spellID)
    local ok, mana = pcall(function()
        for _, cost in ipairs(C_Spell.GetSpellPowerCost(spellID) or {}) do
            if cost.type == PT.Mana then return true end
        end
        return false
    end)
    return (not ok) or mana
end

function fsr:on() return (db.other.fsr.show and self.classes[class]) and true or false end

function fsr:sync()
    local o = db.other.fsr
    local bar = frames[o.bar]
    local host = (bar and bar:IsShown()) and bar or anchor
    self.frame:SetParent(host)
    self.frame:SetFrameLevel(host:GetFrameLevel() + 20) -- over the bars, like the in-combat icon
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", host, "CENTER", o.x, o.y)
    self.frame:SetSize(o.size, o.size)
    self.frame:SetSwipeColor(o.color[1], o.color[2], o.color[3], o.color[4])
    self.frame:SetReverse(o.fill and true or false) -- fill up, or drain away
    if self:on() and ns.previewing() then
        self.frame:SetCooldown(GetTime(), 3600) -- a sweep too slow to see: a full ring, to place it
        self.endTime = nil
        self.frame:Show()
    else
        self.frame:SetShown(self:on() and (self.endTime or 0) > GetTime())
    end
end

-- In combat the window is the plain five-second rule; out of combat regen takes until the
-- seventh second to come back.
function fsr:start()
    if not self:on() then return end
    local seconds = inCombat and 5 or 7
    self.endTime = GetTime() + seconds
    self:sync()
    self.frame:SetCooldown(GetTime(), seconds)
    self.frame:Show()
    C_Timer.After(seconds, function() pcall(self.sync, self) end) -- safe() isn't defined yet
end

-- The window opens when the mana is paid: at cast start, or on success for an instant. A cast
-- that failed never paid, so it takes the spinner back down.
function fsr:cast(event, castGUID, spellID)
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        if self.costsMana(spellID) then
            self.castID = castGUID
            self:start()
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if castGUID ~= self.castID and self.costsMana(spellID) then self:start() end
    elseif event == "UNIT_SPELLCAST_FAILED" and castGUID == self.castID then
        self.endTime = nil
        self:sync()
    end
end

local function setHover(on)
    if on == (hovered or false) then return end
    hovered = on
    for _, f in pairs(frames) do
        for _, s in ipairs(f.segs) do s.hl:SetShown(on) end
    end
    for _, s in ipairs(frames.enemyhealth.resFrame.segs) do s.hl:SetShown(on) end
end

-- IsMouseOver works without EnableMouse, so the highlight never blocks clicks.
local function checkHover() setHover(anchor:IsMouseOver()) end

-- Blizzard's raid and party frames get a see-through overlay while hovered. Kept in a table of
-- our own rather than on the frame, so nothing of Blizzard's secure frame table is written to.
-- Nameplates are set up by the same function; only the named party and raid frames are wanted.
ns.raidHover = setmetatable({}, { __mode = "k" }) -- frame -> overlay texture
pcall(hooksecurefunc, "CompactUnitFrame_SetUpFrame", function(frame)
    local name = frame:GetName() or ""
    if ns.raidHover[frame] or not (name:find("^CompactParty") or name:find("^CompactRaid")) then return end
    local tex = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetAllPoints()
    tex:Hide()
    ns.raidHover[frame] = tex
    frame:HookScript("OnEnter", function()
        if not db.other.raidHover.show then return end
        tex:SetColorTexture(unpack(db.other.raidHover.color))
        tex:Show()
    end)
    frame:HookScript("OnLeave", function() tex:Hide() end)
end)

-- Blizzard UI elements that can show only on mouseover. Protected bars may not be hidden in
-- combat, but their alpha may change: invisible, still clickable, keybinds still work.
local HOVER_FRAMES = {
    { "bar1", "Action bar 1", "MainActionBar" }, { "bar2", "Action bar 2", "MultiBarBottomLeft" },
    { "bar3", "Action bar 3", "MultiBarBottomRight" }, { "bar4", "Action bar 4", "MultiBarRight" },
    { "bar5", "Action bar 5", "MultiBarLeft" }, { "bar6", "Action bar 6", "MultiBar5" },
    { "bar7", "Action bar 7", "MultiBar6" }, { "bar8", "Action bar 8", "MultiBar7" },
    { "stance", "Stance bar", "StanceBar" }, { "pet", "Pet bar", "PetActionBar" },
    { "micro", "Micro menu", "MicroMenuContainer" }, { "bags", "Bag bar", "BagsBar" },
}
ns.FADE_TIME = 0.2
local faded = {} -- frame -> alpha we set

local hoverTicker = CreateFrame("Frame")
ns.hoverTicker = hoverTicker
-- Touching one of Blizzard's own bars is what taints it, and a tainted bar cannot be given the
-- secret numbers its cooldowns are made of -- so it is touched only when the alpha really
-- moves, never once it has settled at either end.
local function hoverTick(_, elapsed)
    local editing = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    local step = math.min(elapsed / ns.FADE_TIME, 1)
    for _, e in ipairs(HOVER_FRAMES) do
        local f = _G[e[3]]
        if f and db.other.hover[e[1]] then
            local want = (editing or f:IsMouseOver()) and 1 or 0
            local was = faded[f] or f:GetAlpha()
            local a = was + math.max(-step, math.min(step, want - was))
            if math.abs(a - was) > 0.001 then
                f:SetAlpha(a)
                faded[f] = a
            else
                faded[f] = was
            end
        elseif f and faded[f] then -- option turned off: back to normal, once
            f:SetAlpha(1)
            faded[f] = nil
        end
    end
end

local function syncHover()
    local any = false
    for _, e in ipairs(HOVER_FRAMES) do any = any or db.other.hover[e[1]] or false end
    if any or next(faded) then
        hoverTicker:SetScript("OnUpdate", hoverTick)
        if not any then hoverTick(nil, 0); hoverTicker:SetScript("OnUpdate", nil) end
    end
end

-- Bag bar only while bags are open, attached to them. Parked under the hidden frame otherwise
-- (so Blizzard showing it doesn't reveal it); its Edit Mode spot is restored when turned off.
local bagsHooked, bagsParked, bagsSaved

local function openBagFrame()
    for _, f in ipairs({ ContainerFrameCombinedBags, ContainerFrame1 }) do
        if f and f:IsShown() then return f end
    end
end

local function syncBags()
    local bar = BagsBar
    local on = db.other.bagsOnOpen
    if not bar or not (on or bagsSaved) then return end
    if InCombatLockdown() then return end -- reparenting their bar mid-fight is blocked
    if not bagsSaved then -- first use: remember where Edit Mode put it
        bagsSaved = { parent = bar:GetParent() }
        for i = 1, bar:GetNumPoints() do bagsSaved[i] = { bar:GetPoint(i) } end
    end
    if not bagsHooked then
        for _, f in ipairs({ ContainerFrameCombinedBags, ContainerFrame1 }) do
            if f then
                f:HookScript("OnShow", function() syncBags() end)
                f:HookScript("OnHide", function() syncBags() end)
            end
        end
        bagsHooked = true
    end
    local bags = on and openBagFrame()
    bar:ClearAllPoints()
    if bags then
        bar:SetParent(bagsSaved.parent)
        if bags == ContainerFrameCombinedBags then
            bar:SetPoint("BOTTOMRIGHT", bags, "TOPRIGHT", 0, 4)
        else -- separate bags stack upward from the backpack, so go beside it
            bar:SetPoint("BOTTOMRIGHT", bags, "BOTTOMLEFT", -6, 0)
        end
    elseif on then
        bar:SetParent(hider)
    else -- turned off: back to the Edit Mode spot
        bar:SetParent(bagsSaved.parent)
        for _, pt in ipairs(bagsSaved) do bar:SetPoint(unpack(pt)) end
        bagsSaved = nil
    end
end

local mini = {} -- the minimap module: its state and helpers live in one table

-- Anything hung on the minimap must stay out of its layout, or Edit Mode's outline (and the
-- cluster's own sizing) grows around it. Blizzard's own day/night dial does the same.
local function ignoreLayout(f)
    f.ignoreInLayout = true
    return f
end
ns.mini = mini

------------------------------------------------------------------------------------------
-- Minimap: square shape, a 1 px mini.border, a mini.tray that collects the addon buttons around it, and
-- a bar underneath with the time, latency and coordinates.
------------------------------------------------------------------------------------------
mini.SQUARE_MASK, mini.ROUND_MASK = "Interface\\Buttons\\WHITE8X8", "ui-hud-minimap-frame-generic-mask"

-- The minimap's mask can't be nine-sliced, so it stretches to fit: Media/MinimapRound/m<N>.tga
-- are 128 px squares whose corner is N px, and the one whose corner ratio is closest to the
-- radius wanted on this minimap wins.
mini.MINIMAP_MASKS = { 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64 }
mini.MINIMAP_MASK_DIR = "Interface\\AddOns\\" .. ADDON .. "\\Media\\MinimapRound\\m"

function mini.roundedMaskFor(radius, size)
    local wanted, best, bestOff = radius / math.max(size, 1), mini.MINIMAP_MASKS[1], math.huge
    for _, r in ipairs(mini.MINIMAP_MASKS) do
        local off = math.abs(r / 128 - wanted)
        if off < bestOff then best, bestOff = r, off end
    end
    return mini.MINIMAP_MASK_DIR .. best .. ".tga"
end

function mini.minimapMask()
    local m = db.other.minimap
    if not m.square then return mini.ROUND_MASK end
    if m.radius == "round" then return mini.ROUND_MASK end
    if (m.radius or 0) <= 0 then return mini.SQUARE_MASK end
    return mini.roundedMaskFor(m.radius, Minimap:GetWidth())
end

mini.minimapDone = {} -- what we have already changed, so nothing is touched unless asked

function mini.minimapShape()
    local mask = mini.minimapMask()
    if mask == mini.minimapDone.mask then return end
    if not mini.minimapDone.mask and mask == mini.ROUND_MASK then return end -- default shape: leave it alone
    mini.minimapDone.mask = mask
    Minimap:SetMaskTexture(mask)
    if MinimapCompassTexture then -- the round frame art only fits the round mask
        MinimapCompassTexture:SetAlpha(mask == mini.ROUND_MASK and 1 or 0)
    end
end

-- The mini.border is a black plate behind the minimap, 1 px larger and cut to the same shape, so it
-- shows as an outline whatever the corners look like.
function mini.minimapBorder()
    local want = db.other.minimap.border and true or false
    if not mini.border then
        if not want then return end
        mini.border = ignoreLayout(CreateFrame("Frame", nil, MinimapCluster or UIParent))
        mini.border:SetFrameLevel(math.max(Minimap:GetFrameLevel() - 1, 0))
        mini.border:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -1, 1)
        mini.border:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 1, -1)
        mini.border.tex = mini.border:CreateTexture(nil, "BACKGROUND")
        mini.border.tex:SetAllPoints()
        mini.border.tex:SetColorTexture(0, 0, 0, 1)
        mini.border.mask = mini.border:CreateMaskTexture()
        mini.border.mask:SetAllPoints(mini.border.tex)
    end
    mini.border:SetShown(want)
    if not want then return end
    local mask = mini.minimapMask()
    if mask == mini.ROUND_MASK or mask == mini.SQUARE_MASK then
        if mini.border.masked then
            mini.border.tex:RemoveMaskTexture(mini.border.mask)
            mini.border.masked = nil
        end
        if mask == mini.ROUND_MASK then -- the round minimap brings its own frame art
            mini.border:Hide()
        end
    else
        mini.border.mask:SetTexture(mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if not mini.border.masked then
            mini.border.tex:AddMaskTexture(mini.border.mask)
            mini.border.masked = true
        end
    end
end

-- What the mini.tray leaves alone: the minimap's own parts and the mini.tray itself. Our own icon goes in
-- like any other addon's.
mini.TRAY_SKIP = { MinimapZoomIn = true, MinimapZoomOut = true, MinimapCompassTexture = true,
    MinimapBackdrop = true, MinimapCluster = true, WolfpackAddonTray = true,
    MinimapZoneTextButton = true, MinimapNorthTag = true, MinimapBorderTop = true }

mini.trayHeld = {} -- button -> { parent, points } so everything can go back
mini.strayText = {} -- loose counter font strings on the minimap, hidden while the mini.tray is on

-- A button's counter usually travels with it. One left behind on the minimap itself (a number
-- floating next to nothing) is hidden while the mini.tray is on, and shown again afterwards.
function mini.trayStrayText(hide)
    for _, holder in ipairs({ Minimap, MinimapCluster }) do
        for _, region in ipairs(holder and holder.GetRegions and { holder:GetRegions() } or {}) do
            if region:IsObjectType("FontString") and tonumber((region:GetText() or ""):match("^%s*(%d+)%s*$" ) or "") then
                if hide then
                    if mini.strayText[region] == nil then mini.strayText[region] = region:IsShown() end
                    region:Hide()
                elseif mini.strayText[region] ~= nil then
                    region:SetShown(mini.strayText[region])
                    mini.strayText[region] = nil
                end
            end
        end
    end
end

-- The mini.tray rides the minimap's edge: a circle when it's round, the square's edge when it's square
-- (the same angle, pushed out until it meets the side).
function mini.trayPlace()
    if not mini.tray then return end
    local angle = math.rad(store.trayAngle or 180)
    local x, y = math.cos(angle), math.sin(angle)
    if db.other.minimap.square then
        local m = math.max(math.abs(x), math.abs(y))
        if m > 0 then x, y = x / m, y / m end
    end
    local out = Minimap:GetWidth() / 2 + 6
    mini.tray:ClearAllPoints()
    mini.tray:SetPoint("CENTER", Minimap, "CENTER", x * out, y * out)
end

-- Minimap buttons are Buttons, but some are Frames carrying their own button and counter text;
-- anything named, mouse-enabled and icon-sized counts, so a counter travels with its icon.
function mini.trayWorthy(f)
    local name = f.GetName and f:GetName()
    if not name or mini.TRAY_SKIP[name] or not f.GetWidth then return false end
    local w = f:GetWidth() or 0
    if w < 12 or w > 48 then return false end
    return f:IsObjectType("Button") or (f.IsMouseEnabled and f:IsMouseEnabled())
end

function mini.trayCollect()
    local found = {}
    for _, parent in ipairs({ Minimap, MinimapBackdrop, MinimapCluster }) do
        for _, child in ipairs(parent and parent.GetChildren and { parent:GetChildren() } or {}) do
            if mini.trayWorthy(child) then found[#found + 1] = child end
        end
    end
    if db.other.minimap.trayBlizzard then
        for _, f in ipairs({ MinimapCluster and MinimapCluster.Tracking, GameTimeFrame }) do
            if f then found[#found + 1] = f end
        end
    end
    return found
end

-- Counters drawn on a collected icon are noise once it sits in the tray.
function mini.trayNumbers(f, hide, kept)
    for _, region in ipairs(f.GetRegions and { f:GetRegions() } or {}) do
        if region:IsObjectType("FontString") and tonumber((region:GetText() or ""):match("^%s*(%d+)%s*$") or "") then
            if hide then
                kept.numbers[region] = region:IsShown()
                region:Hide()
            elseif kept.numbers[region] ~= nil then
                region:SetShown(kept.numbers[region])
            end
        end
    end
end

function mini.trayRelease(f)
    local kept = mini.trayHeld[f]
    if not kept then return end
    mini.trayNumbers(f, false, kept)
    f:SetParent(kept.parent)
    f:SetFrameStrata(kept.strata)
    f:SetFrameLevel(kept.level)
    f:ClearAllPoints()
    for _, pt in ipairs(kept.points) do f:SetPoint(unpack(pt)) end
    mini.trayHeld[f] = nil
end

function mini.trayLayout()
    local held, cell = {}, 28
    for f in pairs(mini.trayHeld) do
        held[#held + 1] = f
        cell = math.max(cell, math.min((f:GetWidth() or 0) + 2, 48)) -- the biggest icon sets the grid
    end
    table.sort(held, function(a, b) return (a:GetName() or "") < (b:GetName() or "") end)
    local perRow = math.min(math.max(#held, 1), 4)
    for i, f in ipairs(held) do
        f:ClearAllPoints()
        f:SetPoint("CENTER", mini.trayPanel, "TOPLEFT",
            6 + cell / 2 + ((i - 1) % 4) * cell, -6 - cell / 2 - math.floor((i - 1) / 4) * cell)
        f:SetFrameStrata("MEDIUM") -- the backdrop sits in BACKGROUND strata, so icons stay above it
        f:SetFrameLevel(mini.trayPanel:GetFrameLevel() + 2)
    end
    mini.trayPanel:SetSize(12 + perRow * cell, 12 + math.ceil(#held / 4) * cell)
    mini.trayPanel:SetShown(#held > 0 and mini.trayPanel.open or false)
    mini.trayBg:SetShown(mini.trayPanel:IsShown())
end

function mini.trayUpdate()
    local on = db.other.minimap.tray
    if not mini.tray then
        if not on then return end
        mini.tray = ignoreLayout(CreateFrame("Button", "WolfpackAddonTray", Minimap))
        mini.tray:SetSize(28, 28)
        mini.tray:SetFrameStrata("MEDIUM")
        mini.tray:SetFrameLevel(Minimap:GetFrameLevel() + 20) -- above the minimap and its mini.border
        local icon = mini.tray:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(133633) -- a bag: the mini.tray holds the other icons
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        mini.tray:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        mini.tray:RegisterForDrag("LeftButton")
        mini.tray:SetScript("OnDragStart", function(self)
            self:SetScript("OnUpdate", function()
                local mx, my = Minimap:GetCenter()
                local cx, cy = GetCursorPosition()
                local scale = Minimap:GetEffectiveScale()
                store.trayAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
                mini.trayPlace()
            end)
        end)
        mini.tray:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
        mini.trayPanel = ignoreLayout(CreateFrame("Frame", nil, mini.tray))
        mini.trayPanel:SetPoint("TOPRIGHT", mini.tray, "TOPLEFT", -4, 0)
        mini.trayPanel:SetFrameStrata("MEDIUM")
        mini.trayPanel:Hide()
        -- the backdrop is its own frame in the lowest strata, so no icon can end up under it
        mini.trayBg = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        mini.trayBg:SetFrameStrata("BACKGROUND")
        mini.trayBg:SetPoint("TOPLEFT", mini.trayPanel, "TOPLEFT")
        mini.trayBg:SetPoint("BOTTOMRIGHT", mini.trayPanel, "BOTTOMRIGHT")
        mini.trayBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1 })
        mini.trayBg:SetBackdropColor(0, 0, 0, 0.85)
        mini.trayBg:SetBackdropBorderColor(0, 0, 0, 1)
        mini.tray:SetScript("OnClick", function()
            mini.trayPanel.open = not mini.trayPanel.open
            mini.trayLayout()
        end)
    end
    mini.tray:SetShown(on)
    if on then
        mini.trayPlace()
        for _, f in ipairs(mini.trayCollect()) do
            if not mini.trayHeld[f] then
                local points = {}
                for i = 1, f:GetNumPoints() do points[i] = { f:GetPoint(i) } end
                mini.trayHeld[f] = { parent = f:GetParent(), points = points, numbers = {},
                    strata = f:GetFrameStrata(), level = f:GetFrameLevel() }
                mini.trayNumbers(f, true, mini.trayHeld[f])
                f:SetParent(mini.trayPanel)
            end
        end
    else
        for f in pairs(mini.trayHeld) do mini.trayRelease(f) end
        if mini.trayPanel then mini.trayPanel:Hide() end
    end
    mini.trayStrayText(on)
    if mini.trayPanel then mini.trayLayout() end
end
-- Two strips: the zone and coordinates above the minimap, the time and latency below it.
mini.blizzBars = {} -- Blizzard's zone text and clock, hidden while ours are up

function mini.makeBar(where)
    local bar = ignoreLayout(CreateFrame("Frame", nil, Minimap))
    bar:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", 0, 2)
    bar:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", 0, 2)
    if where == "bottom" then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, -2)
        bar:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -2)
    end
    bar:SetHeight(14)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)
    for _, side in ipairs({ { "left", "LEFT", 4 }, { "right", "RIGHT", -4 } }) do
        local fs = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint(side[2], side[3], 0)
        fs:SetJustifyH(side[2])
        bar[side[1]] = fs
    end
    return bar
end

function mini.minimapInfo()
    local on = db.other.minimap.infoBar
    if not mini.infoBar then
        if not on then return end
        mini.topBar, mini.infoBar = mini.makeBar("top"), mini.makeBar("bottom")
        mini.topBar.left:SetPoint("RIGHT", mini.topBar.right, "LEFT", -6, 0) -- a long zone name gets cut, not overlapped
        mini.topBar.left:SetJustifyH("LEFT")
        mini.topBar.left:SetWordWrap(false)
        mini.infoBar.next = 0
        mini.infoBar:SetScript("OnUpdate", function(self, elapsed)
            self.next = self.next - elapsed
            if self.next > 0 then return end
            self.next = 1
            self.left:SetText(date("%H:%M"))
            local _, _, _, world = GetNetStats()
            self.right:SetText((world or 0) .. " ms")
            mini.topBar.left:SetText(GetMinimapZoneText() or "")
            local map = C_Map.GetBestMapForUnit("player")
            local pos = map and C_Map.GetPlayerMapPosition(map, "player")
            local x, y
            if pos then x, y = pos:GetXY() end -- "and" would keep only the first return
            mini.topBar.right:SetText(x and string.format("%.1f, %.1f", x * 100, y * 100) or "--")
        end)
    end
    mini.infoBar:SetShown(on)
    mini.topBar:SetShown(on)
    -- Blizzard's own zone name and clock would sit on top of ours
    -- the zone text, its dark backing strip, and the clock
    for _, f in ipairs({ MinimapCluster and MinimapCluster.ZoneTextButton,
        MinimapCluster and MinimapCluster.BorderTop, TimeManagerClockButton }) do
        if type(f) == "table" and f.IsShown then
            if on then
                if mini.blizzBars[f] == nil then mini.blizzBars[f] = f:IsShown() end
                f:Hide()
            elseif mini.blizzBars[f] ~= nil then
                f:SetShown(mini.blizzBars[f])
                mini.blizzBars[f] = nil
            end
        end
    end
end

-- Forever's day/night dial in the minimap's corner (its own frame, not the calendar button).
function mini.minimapDayNight()
    local dial = MinimapCluster and MinimapCluster.DielFrame
    local hide = db.other.minimap.hideDayNight and true or false
    if type(dial) ~= "table" or not dial.Hide or hide == (mini.dayNightShown == false) then return end
    if hide then
        mini.dayNightShown = false
        dial:Hide()
    elseif mini.dayNightShown == false then
        mini.dayNightShown = nil
        dial:Show()
    end
end

-- Nudging the whole minimap, e.g. tighter into the screen corner. Its Edit Mode anchors are kept
-- and restored; Blizzard re-applies them on layout changes, and Refresh puts the offset back.
function mini.minimapOffset()
    local m = db.other.minimap
    local dx, dy = m.x or 0, m.y or 0
    if not MinimapCluster or (dx == 0 and dy == 0 and not mini.minimapAnchors) then return end
    if not mini.minimapAnchors then
        mini.minimapAnchors = {}
        for i = 1, MinimapCluster:GetNumPoints() do mini.minimapAnchors[i] = { MinimapCluster:GetPoint(i) } end
    end
    if dx == 0 and dy == 0 then -- back to where Edit Mode had it
        MinimapCluster:ClearAllPoints()
        for _, pt in ipairs(mini.minimapAnchors) do MinimapCluster:SetPoint(unpack(pt)) end
        mini.minimapAnchors = nil
        return
    end
    MinimapCluster:ClearAllPoints()
    for _, pt in ipairs(mini.minimapAnchors) do
        MinimapCluster:SetPoint(pt[1], pt[2], pt[3], (pt[4] or 0) + dx, (pt[5] or 0) + dy)
    end
end

function mini.syncMinimap()
    if not Minimap then return end
    if InCombatLockdown() then return end -- the cluster is theirs, and off limits in a fight
    mini.minimapShape()
    mini.minimapBorder()
    mini.trayUpdate()
    mini.minimapInfo()
    mini.minimapDayNight()
    mini.minimapOffset()
end

local function Refresh()
    if not moving then place() end -- keeps the pinned edge right after any settings change
    ft.tick() -- takeoff and landing, so a route gets timed whether the bar is shown or not
    local health = frames.health
    local eh, ef = db.regular.bars.enemyhealth, frames.enemyhealth
    health.split = (eh.show and eh.beside and (UnitExists("target") or ns.previewing())) and true or false
    stack(anchor, frames, db.regular, true, swingFrames.regular)
    if health.split and health:IsShown() then
        -- the other half of your health bar's width, and all of its height
        ef:Show()
        local pc = db.regular.bars.pethealth
        local hh = db.regular.bars.health.height + (ns.petBelow() and pc.height + db.regular.gap or 0)
        layoutBar(ef, 1, health.width, { height = ns.totBelow() and math.max(2, hh - ns.totShare()) or hh })
        ns.fill(ef)
        ef:ClearAllPoints()
        ef:SetPoint("TOPLEFT", health, "TOPRIGHT", db.regular.gap, 0)
        ns.layoutRes(ef)
        ns.layoutTag(ef)
        ns.layoutAuras(ef)
        ns.layoutBadges(ef)
    end
    ns.placeToT()
    ns.placePet()
    local plate = targetPlate()
    plateAnchor:SetParent(plate or anchor)
    plateAnchor:SetShown(plate ~= nil)
    if plate then
        plateAnchor:ClearAllPoints()
        plateAnchor:SetPoint(growEdge(db.nameplate), plate, "BOTTOM", db.nameplate.x, db.nameplate.y)
    end
    stack(plateAnchor, plateFrames, db.nameplate, plate ~= nil, swingFrames.nameplate)
    for _, h in pairs(questHolders) do styleQuest(h) end
    mover:SetShown(not db.locked)
    moverHint:SetFormattedText(HINT, db.regular.x, db.regular.y)
    syncProtected()
    syncGryphons()
    bf.refresh()
    mg.refresh()
    hn.refresh()
    wl.refresh()
    we.refresh("rogue")
    we.refresh("shaman")
    fsr:sync()
    syncHover()
    syncBags()
    mini.syncMinimap()
    anchor:SetScript("OnUpdate", db.regular.highlight.show and checkHover or nil)
    if not db.regular.highlight.show then setHover(false) end
end

-- One report per session, printed to chat: Lua errors are hidden by default and this client
-- stops delivering them after 100.
-- GetMoneyString is what this client has; GetCoinTextureString is not here at all.
function ns.money(c) -- on the namespace, not a local: this chunk is at Lua's 200-local ceiling
    local ok, text = pcall(GetMoneyString, c)
    return (ok and text) or tostring(math.floor((c or 0) / 10000)) .. "g"
end

local function safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not ns.errored then
        ns.errored = true
        print("|cffff5555Wolfpack Addon error:|r " .. tostring(err))
    end
end

bf = { rows = {} }
ns.bf = bf

------------------------------------------------------------------------------------------
-- Buff check: out of combat, who in the group is missing a buff that somebody here can give.
-- Only out of combat, because that is the only time this client answers aura questions -- and
-- it is the only time the answer is any use, since you buff before the pull.
------------------------------------------------------------------------------------------
-- One entry per buff a class hands out. `names` are all the spellings that satisfy it, so a
-- greater blessing counts as a blessing and Prayer of Fortitude counts as stamina. A paladin
-- can only keep one blessing on someone, so any single one satisfies the row.
bf.checks = {
    { key = "stamina", from = "PRIEST", label = "Stamina", icon = 1243,
        names = { "Power Word: Fortitude", "Prayer of Fortitude" } },
    { key = "spirit", from = "PRIEST", label = "Spirit", icon = 14752,
        names = { "Divine Spirit", "Prayer of Spirit" } },
    { key = "shadow", from = "PRIEST", label = "Shadow Protection", icon = 976,
        names = { "Shadow Protection", "Prayer of Shadow Protection" } },
    { key = "wild", from = "DRUID", label = "Mark of the Wild", icon = 1126,
        names = { "Mark of the Wild", "Gift of the Wild" } },
    { key = "thorns", from = "DRUID", label = "Thorns", icon = 467, names = { "Thorns" }, off = true },
    { key = "intellect", from = "MAGE", label = "Intellect", icon = 1459,
        names = { "Arcane Intellect", "Arcane Brilliance" } },
    { key = "blessing", from = "PALADIN", label = "A blessing", icon = 19740,
        names = { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings",
            "Blessing of Salvation", "Blessing of Sanctuary", "Blessing of Light",
            "Greater Blessing of Might", "Greater Blessing of Wisdom", "Greater Blessing of Kings",
            "Greater Blessing of Salvation", "Greater Blessing of Sanctuary",
            "Greater Blessing of Light" } },
    { key = "shout", from = "WARRIOR", label = "Battle Shout", icon = 6673,
        names = { "Battle Shout" }, off = true },
}

-- Classes that should have something on their weapon: a rogue's poison, a shaman's enchant.
bf.weaponClasses = { ROGUE = true, SHAMAN = true }


bf.panel = CreateFrame("Frame", "WolfpackAddonBuffCheck", UIParent)
bf.panel:SetSize(200, 20)
bf.panel:SetMovable(true)
bf.panel:SetClampedToScreen(true)
bf.panel:RegisterForDrag("LeftButton")
bf.panel:SetScript("OnDragStart", function(a) a:StartMoving() end)
bf.panel:SetScript("OnDragStop", function(a)
    a:StopMovingOrSizing()
    local ux, uy = UIParent:GetCenter()
    db.buffs.x = math.floor(a:GetCenter() - ux + 0.5)
    db.buffs.y = math.floor(select(2, a:GetCenter()) - uy + 0.5)
    changed()
end)

function bf.icon(id)
    if not id then return 134400 end -- a question mark, for anything the client won't name
    bf.textures = bf.textures or {}
    if bf.textures[id] == nil then
        local ok, tex = pcall(function()
            return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id))
                or GetSpellTexture(id)
        end)
        bf.textures[id] = (ok and tex) or 134400
    end
    return bf.textures[id]
end

-- The units to check, and which classes are here to hand buffs out.
function bf.roster()
    local units, classes = { "player" }, {}
    if IsInRaid() then
        units = {}
        for i = 1, GetNumGroupMembers() or 0 do units[#units + 1] = "raid" .. i end
    else
        for i = 1, (GetNumGroupMembers() or 1) - 1 do units[#units + 1] = "party" .. i end
    end
    for _, u in ipairs(units) do
        if UnitExists(u) then
            local _, token = UnitClass(u)
            if token then classes[token] = true end
        end
    end
    return units, classes
end

-- Does this unit have any of these auras? Out of combat the game answers by name.
function bf.unitHas(unit, names)
    for _, name in ipairs(names) do
        local ok, data = pcall(function()
            local d = C_UnitAuras.GetAuraDataBySpellName(unit, name, "HELPFUL")
            if d then return d end
        end)
        if ok and data then return true, data end
    end
    return false
end

-- Minutes left on one of your own buffs, or nil when it cannot be worked out.
function bf.left(data)
    local ok, left = pcall(function()
        local exp = data.expirationTime
        if readable(exp) and exp and exp > 0 then return exp - GetTime() end
    end)
    return ok and left or nil
end

function bf.short(sec)
    if not sec or sec <= 0 then return "" end
    if sec >= 3600 then return math.floor(sec / 3600 + 0.5) .. "h" end
    if sec >= 60 then return math.floor(sec / 60 + 0.5) .. "m" end
    return math.floor(sec) .. "s"
end

-- A name for the list of who is missing something: first name, shortened.
function bf.who(unit)
    local n = UnitName(unit) or "?"
    n = n:match("^[^%s%-]+") or n
    return n:sub(1, 10)
end

function bf.row(i)
    local o = db.buffs
    local r = bf.rows[i]
    if not r then
        r = CreateFrame("Frame", nil, bf.panel)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.icon:SetPoint("LEFT")
        r.text = r:CreateFontString(nil, "OVERLAY")
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
        r.text:SetJustifyH("LEFT")
        bf.rows[i] = r
    end
    r:SetSize(260, o.size)
    r.icon:SetSize(o.size, o.size)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", bf.panel, "TOPLEFT", 0, -(i - 1) * (o.size + 2))
    local flags = o.outline and "OUTLINE" or ""
    if not r.text:SetFont(o.font, o.fontSize, flags) then r.text:SetFont(FONTS[1][2], o.fontSize, flags) end
    r:Show()
    return r
end

-- Builds the list: one row per buff somebody here can give, plus your weapon and your timers.
function bf.check()
    local o, lines = db.buffs, {}
    local units, classes = bf.roster()
    for _, chk in ipairs(bf.checks) do
        if classes[chk.from] and not o.skip[chk.key] and not (chk.off and o.skip[chk.key] ~= false) then
            local missing, mineLeft = {}, nil
            for _, u in ipairs(units) do
                if UnitExists(u) and not UnitIsDeadOrGhost(u) then
                    local has, data = bf.unitHas(u, chk.names)
                    if not has then
                        missing[#missing + 1] = bf.who(u)
                    elseif u == "player" then
                        mineLeft = bf.left(data)
                    end
                end
            end
            local text
            if #missing == 0 then
                text = chk.label .. ": all set" .. (mineLeft and (" (you " .. bf.short(mineLeft) .. ")") or "")
            elseif #missing > 4 then
                text = chk.label .. ": " .. #missing .. " missing"
            else
                text = chk.label .. ": " .. table.concat(missing, ", ")
            end
            lines[#lines + 1] = { icon = chk.icon, text = text, ok = #missing == 0 }
        end
    end
    -- Your weapon: a rogue's poison or a shaman's enchant, with what is left on it.
    if bf.weaponClasses[class or ""] and not o.skip.weapon then
        local ok, hasMain, mainMs, _, _, hasOff, offMs = pcall(GetWeaponEnchantInfo)
        if ok then
            local text = "Weapon: "
            if hasMain then text = text .. "main " .. bf.short((mainMs or 0) / 1000) else text = text .. "main missing" end
            if hasOff then
                text = text .. ", off " .. bf.short((offMs or 0) / 1000)
            elseif OffhandHasWeapon and OffhandHasWeapon() then
                text = text .. ", off missing"
            end
            lines[#lines + 1] = { icon = 135795, text = text, ok = hasMain and true or false }
        end
    end
    return lines
end

function bf.refresh()
    if not db then return end
    local o = db.buffs
    bf.panel:ClearAllPoints()
    bf.panel:SetPoint("CENTER", UIParent, "CENTER", o.x, o.y)
    bf.panel:EnableMouse(not o.locked)
    -- In combat the game answers nothing, so the list would be a guess: it steps aside instead.
    if not o.show or (InCombatLockdown() and not ns.previewing()) then
        bf.panel:Hide()
        return
    end
    bf.panel:Show()
    local lines = bf.check()
    local n = 0
    for _, line in ipairs(lines) do
        if not (line.ok and o.onlyMissing) then
            n = n + 1
            local r = bf.row(n)
            r.icon:SetTexture(bf.icon(line.icon))
            r.icon:SetDesaturated(line.ok and true or false)
            r.text:SetText(line.text)
            if line.ok then
                r.text:SetTextColor(0.5, 0.8, 0.5, 1)
            else
                r.text:SetTextColor(unpack(o.color))
            end
        end
    end
    if n == 0 and ns.previewing() then -- something to grab while placing it
        n = 1
        local r = bf.row(1)
        r.icon:SetTexture(bf.icon(1243))
        r.text:SetText("Buff check: all set")
        r.text:SetTextColor(0.5, 0.8, 0.5, 1)
    end
    for i = n + 1, #bf.rows do bf.rows[i]:Hide() end
    bf.panel:SetSize(260, math.max(n * (o.size + 2), 20))
end

ns.BUFF_CHECKS = bf.checks

local bfEv = CreateFrame("Frame")
ns.bfEv = bfEv
bfEv:SetScript("OnEvent", function() safe(bf.refresh) end)
for _, e in ipairs({ "UNIT_AURA", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED", "PLAYER_ALIVE", "GROUP_ROSTER_UPDATE", "PLAYER_DEAD",
    "UNIT_INVENTORY_CHANGED" }) do
    pcall(bfEv.RegisterEvent, bfEv, e)
end

------------------------------------------------------------------------------------------
-- Mage: how much conjured food and water is in the bags, always the best rank you carry.
------------------------------------------------------------------------------------------
mg = { entries = {} }
ns.mg = mg

-- Rounded icons use a mask of their own, scaled to the icon: the bars' nine-slice masks are
-- cut for long bars and collapse at icon size, which is what squeezed the art into a corner.
-- The radius is a share of the icon, so 12 and 25 are gentle and 50 is a circle.
ns.ICON_MASKS = { [12] = "i12", [25] = "i25", [50] = "i50" }

function ns.iconCorners(tex, mask, radius, coords)
    local file = ns.ICON_MASKS[radius]
    -- A mask covers the whole texture, not the part SetTexCoord kept, so a rounded icon is
    -- shown whole; a square one keeps the usual trim of its own border.
    tex:SetTexCoord(unpack(coords or (file and { 0, 1, 0, 1 }) or { 0.08, 0.92, 0.08, 0.92 }))
    if file then
        if mask.icon ~= file then
            mask:SetTexture("Interface\\AddOns\\WolfpackAddon\\Media\\Icon\\" .. file .. ".tga",
                "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask.icon = file
        end
        if not tex.iconMask then
            tex:AddMaskTexture(mask)
            tex.iconMask = true
        end
    elseif tex.iconMask then
        tex:RemoveMaskTexture(mask)
        tex.iconMask = nil
    end
end
-- Item id and the level it starts at, lowest rank first.
mg.ranks = {
    food = { { 5349, 1 }, { 1113, 5 }, { 1114, 15 }, { 1487, 25 }, { 8075, 35 }, { 8076, 45 },
        { 22895, 55 } },
    water = { { 5350, 1 }, { 2288, 5 }, { 2136, 15 }, { 3772, 25 }, { 8077, 35 }, { 8078, 45 },
        { 8079, 55 } },
}

mg.panel = CreateFrame("Frame", "WolfpackAddonMage", UIParent)
mg.panel:SetSize(80, 32)
mg.panel:SetMovable(true)
mg.panel:SetClampedToScreen(true)
mg.panel:RegisterForDrag("LeftButton")
mg.panel:SetScript("OnDragStart", function(a) a:StartMoving() end)
mg.panel:SetScript("OnDragStop", function(a)
    a:StopMovingOrSizing()
    local ux, uy = UIParent:GetCenter()
    db.mage.x = math.floor(a:GetCenter() - ux + 0.5)
    db.mage.y = math.floor(select(2, a:GetCenter()) - uy + 0.5)
    changed()
end)

-- The item's own icon, asked for by id so it is right even with empty bags.
function mg.icon(id)
    mg.icons = mg.icons or {}
    if mg.icons[id] == nil then
        local ok, tex = pcall(function()
            return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id))
                or (GetItemIcon and GetItemIcon(id))
        end)
        mg.icons[id] = (ok and tex) or 134062
    end
    return mg.icons[id]
end

-- How many of each conjured item are in the bags, by item id.
function mg.counts()
    local totals = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id then totals[id] = (totals[id] or 0) + (info.stackCount or 1) end
        end
    end
    return totals
end

-- The best rank you carry, or, carrying none, the rank your level can conjure.
function mg.best(kind, totals)
    local ranks = mg.ranks[kind]
    for i = #ranks, 1, -1 do
        local id = ranks[i][1]
        if (totals[id] or 0) > 0 then return id, totals[id] end
    end
    local level, id = (UnitLevel and UnitLevel("player")) or 1, ranks[1][1]
    for _, rank in ipairs(ranks) do
        if level >= rank[2] then id = rank[1] end
    end
    return id, 0
end

function mg.entry(i)
    local e = mg.entries[i]
    if not e then
        e = CreateFrame("Frame", nil, mg.panel)
        e.icon = e:CreateTexture(nil, "ARTWORK")
        e.icon:SetAllPoints()
        e.mask = e:CreateMaskTexture()
        e.mask:SetAllPoints(e)
        e.text = e:CreateFontString(nil, "OVERLAY")
        mg.entries[i] = e
    end
    return e
end

function mg.refresh()
    if not db then return end -- our events can arrive before the profile is loaded
    local o = db.mage
    mg.panel:ClearAllPoints()
    mg.panel:SetPoint("CENTER", UIParent, "CENTER", o.x, o.y)
    mg.panel:EnableMouse(not o.locked)
    if not o.show or class ~= "MAGE" then
        mg.panel:Hide()
        return
    end
    mg.panel:Show()
    local totals = mg.counts()
    local flags = o.outline and "OUTLINE" or ""
    local order = o.waterFirst and { "water", "food" } or { "food", "water" }
    for i, kind in ipairs(order) do
        local id, count = mg.best(kind, totals)
        local e = mg.entry(i)
        e:SetSize(o.size, o.size)
        e:ClearAllPoints()
        local step = o.size + o.gap
        if o.grow == "down" then
            e:SetPoint("TOPLEFT", mg.panel, "TOPLEFT", 0, -(i - 1) * step)
        else
            e:SetPoint("TOPLEFT", mg.panel, "TOPLEFT", (i - 1) * step, 0)
        end
        e.icon:SetTexture(mg.icon(id))
        e.icon:SetDesaturated(count == 0)
        ns.iconCorners(e.icon, e.mask, o.radius)
        if not e.text:SetFont(o.font, o.fontSize, flags) then
            e.text:SetFont(FONTS[1][2], o.fontSize, flags)
        end
        e.text:ClearAllPoints()
        e.text:SetPoint(o.countAt == "center" and "CENTER" or "BOTTOMRIGHT", e, 
            o.countAt == "center" and "CENTER" or "BOTTOMRIGHT", 0, 0)
        e.text:SetText(count)
        e.text:SetShown(o.showCount)
        if count <= o.low then
            e.text:SetTextColor(unpack(o.lowColor))
        else
            e.text:SetTextColor(unpack(o.color))
        end
        e:Show()
    end
    local step = o.size + o.gap
    mg.panel:SetSize(o.grow == "down" and o.size or (step + o.size),
        o.grow == "down" and (step + o.size) or o.size)
end

local mgEv = CreateFrame("Frame")
ns.mgEv = mgEv
mgEv:SetScript("OnEvent", function() safe(mg.refresh) end)
for _, e in ipairs({ "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD",
    "PLAYER_LEVEL_UP", "PLAYER_LOGIN" }) do
    pcall(mgEv.RegisterEvent, mgEv, e)
end

------------------------------------------------------------------------------------------
-- Hunter: how much ammunition is left, and how the pet feels about you.
------------------------------------------------------------------------------------------
-- Blizzard's own happiness art: three faces side by side in one texture. Kept on the module
-- rather than as a local, because this file is at Lua's limit of 200 of them.
hn = { entries = {}, happyArt = "Interface\\PetPaperDollFrame\\UI-PetHappiness" }
ns.hn = hn
hn.panel = CreateFrame("Frame", "WolfpackAddonHunter", UIParent)
hn.panel:SetSize(80, 32)
hn.panel:SetMovable(true)
hn.panel:SetClampedToScreen(true)
hn.panel:RegisterForDrag("LeftButton")
hn.panel:SetScript("OnDragStart", function(a) a:StartMoving() end)
hn.panel:SetScript("OnDragStop", function(a)
    a:StopMovingOrSizing()
    local ux, uy = UIParent:GetCenter()
    db.hunter.x = math.floor(a:GetCenter() - ux + 0.5)
    db.hunter.y = math.floor(select(2, a:GetCenter()) - uy + 0.5)
    changed()
end)

-- What is in the ammo slot, and how much of it you are carrying in total.
function hn.ammo()
    local slot = 0 -- the ammo slot; GetInventorySlotInfo knows it by name on clients that have it
    pcall(function() slot = GetInventorySlotInfo("AmmoSlot") or slot end)
    local okID, id = pcall(GetInventoryItemID, "player", slot)
    local okCount, count = pcall(GetInventoryItemCount, "player", slot)
    local okIcon, icon = pcall(GetInventoryItemTexture, "player", slot)
    if not okID or type(id) ~= "number" then return nil, 0, nil end
    return id, (okCount and type(count) == "number") and count or 0, okIcon and icon or nil
end

-- Happiness has moved around between builds, so every route is tried. This client answers on
-- C_PetInfo.GetPetHappiness; older ones on the bare call, and Blizzard's own indicator frame
-- can be asked directly as a last resort. A failed pcall hands back its error text, and some
-- builds answer with a table, so only a real 1-3 counts.
function hn.happiness()
    for _, get in ipairs({
        function() return C_PetInfo.GetPetHappiness() end,
        function() return PetFrameHappiness:GetHappinessStats() end,
        function() return GetPetHappiness() end,
        function() return UnitPetHappiness("pet") end,
    }) do
        local ok, value = pcall(get)
        if ok and type(value) == "table" then
            value = value.happiness or value.happinessLevel or value.level
        end
        if ok and type(value) == "number" and value >= 1 and value <= 3 then
            return math.floor(value)
        end
    end
end

-- Blizzard's own indicator is already wearing the right face, so it is copied rather than
-- cropped by hand: on this build the art is an atlas, and the old coordinates land on some
-- unrelated corner of the file.
function hn.happyLook()
    local ok, look = pcall(function()
        for _, r in ipairs({ PetFrameHappiness:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "Texture" then
                local atlas = r.GetAtlas and r:GetAtlas()
                if atlas then return { atlas = atlas } end
                local tex = r.GetTexture and r:GetTexture()
                if tex then return { tex = tex, coords = { r:GetTexCoord() } } end
            end
        end
    end)
    return ok and type(look) == "table" and look or nil
end

function hn.entry(i)
    local e = hn.entries[i]
    if not e then
        e = CreateFrame("Frame", nil, hn.panel)
        e.icon = e:CreateTexture(nil, "ARTWORK")
        e.icon:SetAllPoints()
        e.mask = e:CreateMaskTexture()
        e.mask:SetAllPoints(e)
        e.text = e:CreateFontString(nil, "OVERLAY")
        hn.entries[i] = e
    end
    return e
end

function hn.refresh()
    if not db then return end
    local o = db.hunter
    hn.panel:ClearAllPoints()
    hn.panel:SetPoint("CENTER", UIParent, "CENTER", o.x, o.y)
    hn.panel:EnableMouse(not o.locked)
    if not o.show or class ~= "HUNTER" then
        hn.panel:Hide()
        return
    end
    hn.panel:Show()
    local flags = o.outline and "OUTLINE" or ""
    local step, n = o.size + o.gap, 0
    local id, count, tex = hn.ammo()
    local happy = hn.happiness()
    for _, what in ipairs({ "ammo", "pet" }) do
        local show, icon, text, coords, atlas = false, nil, nil, nil, nil
        if what == "ammo" and o.ammo and id then
            show, icon, text = true, tex or 132382, o.showCount and count or nil
        elseif what == "pet" and o.pet and happy and UnitExists("pet") then
            show = true
            local look = hn.happyLook()
            if look and look.atlas then
                atlas = look.atlas
            elseif look and look.tex then
                icon, coords = look.tex, look.coords
            else -- the old file, cut into three faces side by side
                icon = hn.happyArt
                coords = { (happy - 1) * 0.1875, happy * 0.1875, 0, 0.359375 }
            end
        end
        if show then
            n = n + 1
            local e = hn.entry(n)
            e:SetSize(o.size, o.size)
            e:ClearAllPoints()
            if o.grow == "down" then
                e:SetPoint("TOPLEFT", hn.panel, "TOPLEFT", 0, -(n - 1) * step)
            else
                e:SetPoint("TOPLEFT", hn.panel, "TOPLEFT", (n - 1) * step, 0)
            end
            e.icon:SetTexture(icon)
            ns.iconCorners(e.icon, e.mask, o.radius, coords)
            if atlas then e.icon:SetAtlas(atlas) end -- an atlas brings its own coordinates
            if not e.text:SetFont(o.font, o.fontSize, flags) then
                e.text:SetFont(FONTS[1][2], o.fontSize, flags)
            end
            e.text:ClearAllPoints()
            local at = o.countAt == "center" and "CENTER" or "BOTTOMRIGHT"
            e.text:SetPoint(at, e, at, 0, 0)
            e.text:SetText(text or "")
            e.text:SetShown(text ~= nil)
            if text and count <= o.low then
                e.text:SetTextColor(unpack(o.lowColor))
            else
                e.text:SetTextColor(unpack(o.color))
            end
            e:Show()
        end
    end
    for i = n + 1, #hn.entries do hn.entries[i]:Hide() end
    hn.panel:SetSize(o.grow == "down" and o.size or math.max(n * step - o.gap, o.size),
        o.grow == "down" and math.max(n * step - o.gap, o.size) or o.size)
end

local hnEv = CreateFrame("Frame")
ns.hnEv = hnEv
hnEv:SetScript("OnEvent", function() safe(hn.refresh) end)
for _, e in ipairs({ "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "UNIT_PET",
    "UNIT_HAPPINESS", "PLAYER_LOGIN", "UNIT_INVENTORY_CHANGED" }) do
    pcall(hnEv.RegisterEvent, hnEv, e)
end

------------------------------------------------------------------------------------------
-- Warlock: how many soul shards are in the bags.
------------------------------------------------------------------------------------------
wl = { shard = 6265 } -- the item id of a Soul Shard
ns.wl = wl
wl.panel = CreateFrame("Frame", "WolfpackAddonWarlock", UIParent)
wl.panel:SetSize(32, 32)
wl.panel:SetMovable(true)
wl.panel:SetClampedToScreen(true)
wl.panel:RegisterForDrag("LeftButton")
wl.panel:SetScript("OnDragStart", function(a) a:StartMoving() end)
wl.panel:SetScript("OnDragStop", function(a)
    a:StopMovingOrSizing()
    local ux, uy = UIParent:GetCenter()
    db.warlock.x = math.floor(a:GetCenter() - ux + 0.5)
    db.warlock.y = math.floor(select(2, a:GetCenter()) - uy + 0.5)
    changed()
end)
wl.entries = {}
wl.armors = { { "Demon Armor", 706, 20 }, { "Demon Skin", 696, 4 } } -- best first, and its level

function wl.entry(i)
    local e = wl.entries[i]
    if not e then
        e = CreateFrame("Frame", nil, wl.panel)
        e.icon = e:CreateTexture(nil, "ARTWORK")
        e.icon:SetAllPoints()
        e.mask = e:CreateMaskTexture()
        e.mask:SetAllPoints(e)
        e.text = e:CreateFontString(nil, "OVERLAY")
        wl.entries[i] = e
    end
    return e
end

-- Shards stack one to a slot, so this counts slots as well as stack sizes.
function wl.count()
    local total = 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == wl.shard then total = total + (info.stackCount or 1) end
        end
    end
    return total
end

function wl.icons(id)
    wl.tex = wl.tex or {}
    if wl.tex[id] == nil then
        local ok, tex = pcall(function()
            if id == wl.shard then
                return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id))
                    or (GetItemIcon and GetItemIcon(id))
            end
            return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id))
                or (GetSpellTexture and GetSpellTexture(id))
        end)
        wl.tex[id] = (ok and tex) or 134336
    end
    return wl.tex[id]
end

-- Is that buff on you? Out of combat the game answers. In a fight it says nothing about any
-- aura -- but Blizzard's own buff buttons are still on screen wearing the icon, and reading a
-- texture off their frame is not an aura call, so it is not cut off. Returns true, false, or
-- nil when nobody will say.
function wl.iconOnBuffBar(tex)
    local found = nil
    pcall(function()
        for i = 1, 40 do
            local b = _G["BuffButton" .. i]
            local art = b and (b.icon or _G["BuffButton" .. i .. "Icon"])
            if not art then break end
            found = found or false
            if art:GetTexture() == tex then found = true end
        end
        if found ~= nil or not BuffFrame then return end
        local holder = BuffFrame.AuraContainer or BuffFrame
        for _, child in ipairs({ holder:GetChildren() }) do
            local art = child.icon or child.Icon
            if art then
                found = found or false
                if art:GetTexture() == tex then found = true end
            end
        end
    end)
    return found
end

-- Which armor should be on you, and whether it is. Either one counts while it is up.
--
-- In a fight nothing will say: the aura calls refuse, and Blizzard's buff icons do not compare
-- reliably either. So what is known out of the fight is remembered, and casting armor during
-- one updates that memory. The buff lasts half an hour; no fight outlives the answer.
function wl.armor()
    local combat = InCombatLockdown()
    local answered = false
    for _, sp in ipairs(wl.armors) do
        if not combat then
            local ok, data = pcall(function()
                local d = C_UnitAuras.GetAuraDataBySpellName("player", sp[1], "HELPFUL")
                if d then return d end
            end)
            if ok then answered = true end
            if ok and data then wl.memoUp, wl.memoSp = true, sp return sp, true end
        end
        if wl.iconOnBuffBar(wl.icons(sp[2])) == true then
            wl.memoUp, wl.memoSp = true, sp
            return sp, true
        end
    end
    -- the one you should be wearing is a question of level -- the spellbook on this client
    -- often answers nothing at all, the level always answers
    local lvl, best = UnitLevel("player") or 0, nil
    for _, sp in ipairs(wl.armors) do
        if lvl >= sp[3] and not best then best = sp end
    end
    if combat then
        if wl.memoUp then return wl.memoSp or best, true end
    elseif answered then
        wl.memoUp, wl.memoSp = false, nil -- out here the game is telling the truth
    end
    return best, false
end

-- Casting it in a fight is the one thing we do get told about.
function wl.sawCast(spellID)
    local ok, name = pcall(function()
        if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
        if type(info) == "table" then return info.name end
        if GetSpellInfo then return (GetSpellInfo(spellID)) end
    end)
    if not ok or type(name) ~= "string" then return end
    for _, sp in ipairs(wl.armors) do
        if name == sp[1] then wl.memoUp, wl.memoSp = true, sp end
    end
end

function wl.refresh()
    if not db then return end
    local o = db.warlock
    wl.panel:ClearAllPoints()
    wl.panel:SetPoint("CENTER", UIParent, "CENTER", o.x, o.y)
    wl.panel:EnableMouse(not o.locked)
    if not o.show or class ~= "WARLOCK" then
        wl.panel:Hide()
        return
    end
    wl.panel:Show()
    local flags, n, step = o.outline and "OUTLINE" or "", 0, o.size + o.gap
    local function place(e, icon, text, colored, size, fontSize)
        n = n + 1
        e:SetSize(size, size)
        e:ClearAllPoints()
        if o.grow == "down" then
            e:SetPoint("TOPLEFT", wl.panel, "TOPLEFT", 0, -(n - 1) * step)
        else
            e:SetPoint("TOPLEFT", wl.panel, "TOPLEFT", (n - 1) * step, 0)
        end
        e.icon:SetTexture(icon)
        ns.iconCorners(e.icon, e.mask, o.radius)
        local fs = fontSize or o.fontSize
        if not e.text:SetFont(o.font, fs, flags) then e.text:SetFont(FONTS[1][2], fs, flags) end
        e.text:ClearAllPoints()
        local at = o.countAt == "center" and "CENTER" or "BOTTOMRIGHT"
        e.text:SetPoint(at, e, at, 0, 0)
        e.text:SetText(text or "")
        e.text:SetShown(o.showCount and text ~= nil)
        e.text:SetTextColor(unpack(colored and o.lowColor or o.color))
        e:Show()
    end

    local count = wl.count()
    place(wl.entry(1), wl.icons(wl.shard), count, count <= o.low, o.size, o.fontSize)
    wl.entry(1).icon:SetDesaturated(count == 0)

    wl.lit = nil
    if o.armor then
        local sp, up = wl.armor()
        -- With "only when missing" on, a buff that is up needs no reminder at all.
        if sp and not (up and o.armorOnlyMissing) then
            local e = wl.entry(2)
            place(e, wl.icons(sp[2]), nil, false, o.armorSize or o.size,
                o.armorFontSize or o.fontSize)
            e.icon:SetDesaturated(false)
            e.icon:SetAlpha(1)
            wl.lit = (not up) and e or nil -- missing: it is the one that flashes
        end
    end
    for i = n + 1, #wl.entries do wl.entries[i]:Hide() end
    wl.panel:SetSize(o.grow == "down" and o.size or math.max(n * step - o.gap, o.size),
        o.grow == "down" and math.max(n * step - o.gap, o.size) or o.size)
end

-- The armor icon breathes while the buff is missing, and the duration ticks down on its own.
wl.ticker = CreateFrame("Frame")
wl.ticker.since = 0
wl.ticker:SetScript("OnUpdate", function(self, elapsed)
    if not db or not db.warlock.show or class ~= "WARLOCK" then return end
    if wl.lit and db.warlock.flash then -- all the way down and back, so it is hard to miss
        self.t = (self.t or 0) + elapsed
        wl.lit.icon:SetAlpha(0.1 + 0.9 * math.abs(math.sin(self.t * 2.6)))
    elseif wl.entries[2] then
        wl.entries[2].icon:SetAlpha(1)
    end
    self.since = self.since + elapsed
    if self.since < 1 then return end
    self.since = 0
    safe(wl.refresh)
end)

local wlEv = CreateFrame("Frame")
ns.wlEv = wlEv
wlEv:SetScript("OnEvent", function(_, ev, unit, _, spellID)
    if ev == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit ~= "player" then return end
        safe(wl.sawCast, spellID)
    end
    safe(wl.refresh)
end)
for _, e in ipairs({ "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "PLAYER_LOGIN",
    "UNIT_AURA", "PLAYER_REGEN_ENABLED", "UNIT_SPELLCAST_SUCCEEDED" }) do
    pcall(wlEv.RegisterEvent, wlEv, e)
end

------------------------------------------------------------------------------------------
-- Weapon enchants: a rogue's poisons, a shaman's imbues. One icon per hand, shown when that
-- weapon has nothing on it, or when what it has is nearly gone. GetWeaponEnchantInfo is
-- inventory, not auras, so it answers in a fight as well as out of one.
------------------------------------------------------------------------------------------
we = { panels = {}, classOf = { rogue = "ROGUE", shaman = "SHAMAN" } }
ns.we = we

function we.panel(key)
    local p = we.panels[key]
    if not p then
        p = { entries = {} }
        p.frame = CreateFrame("Frame", "WolfpackAddon" .. key, UIParent)
        p.frame:SetSize(32, 32)
        p.frame:SetMovable(true)
        p.frame:SetClampedToScreen(true)
        p.frame:RegisterForDrag("LeftButton")
        p.frame:SetScript("OnDragStart", function(a) a:StartMoving() end)
        p.frame:SetScript("OnDragStop", function(a)
            a:StopMovingOrSizing()
            local ux, uy = UIParent:GetCenter()
            db[key].x = math.floor(a:GetCenter() - ux + 0.5)
            db[key].y = math.floor(select(2, a:GetCenter()) - uy + 0.5)
            changed()
        end)
        we.panels[key] = p
    end
    return p
end

function we.entry(p, i)
    local e = p.entries[i]
    if not e then
        e = CreateFrame("Frame", nil, p.frame)
        e.icon = e:CreateTexture(nil, "ARTWORK")
        e.icon:SetAllPoints()
        e.mask = e:CreateMaskTexture()
        e.mask:SetAllPoints(e)
        e.text = e:CreateFontString(nil, "OVERLAY")
        p.entries[i] = e
    end
    return e
end

-- What is on each hand: the weapon's own icon, whether it is enchanted, and the minutes left.
-- In a fight the answer is not to be trusted, and nothing can be done about it anyway, so the
-- last reading from before the fight stands: you went in bare, and the icon keeps saying so.
function we.hands()
    if InCombatLockdown() then return we.cache or {} end
    local ok, hasMain, mainMs, _, _, hasOff, offMs = pcall(GetWeaponEnchantInfo)
    if not ok then return {} end
    local out = {}
    for i, slot in ipairs({ 16, 17 }) do -- main hand, off hand
        local gotIcon, icon = pcall(GetInventoryItemTexture, "player", slot)
        if gotIcon and icon then
            local has = i == 1 and hasMain or hasOff
            local ms = i == 1 and mainMs or offMs
            out[#out + 1] = { icon = icon, has = has and true or false,
                minutes = (type(ms) == "number" and ms > 0) and (ms / 60000) or nil }
        end
    end
    we.cache = out
    return out
end

function we.refresh(key)
    if not db then return end
    local o = db[key]
    local p = we.panel(key)
    p.frame:ClearAllPoints()
    p.frame:SetPoint("CENTER", UIParent, "CENTER", o.x, o.y)
    p.frame:EnableMouse(not o.locked)
    if not o.show or class ~= we.classOf[key] then
        p.frame:Hide()
        return
    end
    p.frame:Show()
    local flags, n, step = o.outline and "OUTLINE" or "", 0, o.size + o.gap
    p.lit = {}
    for _, hand in ipairs(we.hands()) do
        -- Nothing on it: a reminder. Nearly gone, and out of combat where you can do something
        -- about it: the same icon with the minutes left. Otherwise nothing at all.
        local missing = not hand.has
        local low = hand.has and hand.minutes and hand.minutes <= o.warn
            and not InCombatLockdown()
        if missing or low then
            n = n + 1
            local e = we.entry(p, n)
            e:SetSize(o.size, o.size)
            e:ClearAllPoints()
            if o.grow == "down" then
                e:SetPoint("TOPLEFT", p.frame, "TOPLEFT", 0, -(n - 1) * step)
            else
                e:SetPoint("TOPLEFT", p.frame, "TOPLEFT", (n - 1) * step, 0)
            end
            e.icon:SetTexture(hand.icon)
            e.icon:SetAlpha(1)
            ns.iconCorners(e.icon, e.mask, o.radius)
            if not e.text:SetFont(o.font, o.fontSize, flags) then
                e.text:SetFont(FONTS[1][2], o.fontSize, flags)
            end
            e.text:ClearAllPoints()
            local at = o.countAt == "center" and "CENTER" or "BOTTOMRIGHT"
            e.text:SetPoint(at, e, at, 0, 0)
            e.text:SetText(low and (math.floor(hand.minutes) .. "m") or "")
            e.text:SetShown(low and true or false)
            e.text:SetTextColor(unpack(low and o.warnColor or o.color))
            p.lit[n] = missing -- only a bare weapon flashes
            e:Show()
        end
    end
    for i = n + 1, #p.entries do p.entries[i]:Hide() end
    p.frame:SetSize(o.grow == "down" and o.size or math.max(n * step - o.gap, o.size),
        o.grow == "down" and math.max(n * step - o.gap, o.size) or o.size)
end

we.ticker = CreateFrame("Frame")
we.ticker.since = 0
we.ticker:SetScript("OnUpdate", function(self, elapsed)
    if not db then return end
    self.t = (self.t or 0) + elapsed
    local a = 0.1 + 0.9 * math.abs(math.sin(self.t * 2.6))
    for key, p in pairs(we.panels) do
        if db[key] and db[key].flash then
            for i, lit in pairs(p.lit or {}) do
                if lit and p.entries[i] then p.entries[i].icon:SetAlpha(a) end
            end
        end
    end
    self.since = self.since + elapsed
    if self.since < 1 then return end
    self.since = 0
    safe(we.refresh, "rogue")
    safe(we.refresh, "shaman")
end)

ns.weEv = CreateFrame("Frame")
ns.weEv:SetScript("OnEvent", function()
    safe(we.refresh, "rogue")
    safe(we.refresh, "shaman")
end)
for _, e in ipairs({ "UNIT_INVENTORY_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_LOGIN",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "BAG_UPDATE" }) do
    pcall(ns.weEv.RegisterEvent, ns.weEv, e)
end

------------------------------------------------------------------------------------------
-- Options window (/cpd)
------------------------------------------------------------------------------------------
-- section = sidebar entry, sub = tab inside Nameplates, mode = which bar layout is being edited
local cfg, selected, mode, section, sub = nil, "health", "regular", "combat", "bars"
-- Classes the addon has settings of its own for: { section key, label, class token }
ns.CLASS_SECTIONS = { { "hunter", "Hunter", "HUNTER" }, { "mage", "Mage", "MAGE" },
    { "rogue", "Rogue", "ROGUE" }, { "shaman", "Shaman", "SHAMAN" },
    { "warlock", "Warlock", "WARLOCK" } }
local refreshers = {}

changed = function()
    safe(Refresh)
    for _, fn in ipairs(refreshers) do fn() end
end

local function L() return db[mode] end
local function cur() return L().bars[selected] end
local function onRefresh(fn) refreshers[#refreshers + 1] = fn end

-- A titled card that stacks rows: row(h) gives the y for a widget that tall. The lowest card on
-- any page decides how tall the options window needs to be. Look: UI.lua.
local pageBottom = 0
local function group(parent, x, y, w, title)
    ns.boxesOn = ns.boxesOn or {}
    ns.boxesOn[parent] = (ns.boxesOn[parent] or 0) + 1
    local g = { x = x + 12, cursor = y - 34, w = w }
    g.title = parent:CreateFontString(nil, "OVERLAY", ns.ui.HEADING)
    g.title:SetPoint("TOPLEFT", x + 12, y - 12)
    g.title:SetText(title)
    function g:row(h)
        local at = self.cursor
        self.cursor = at - h
        return at
    end
    function g:close()
        local bottom = self.cursor - 8
        pageBottom = math.min(pageBottom, bottom)
        ns.cards = ns.cards or {}
        ns.cards[parent] = ns.cards[parent] or {}
        table.insert(ns.cards[parent], { x = x, bottom = bottom })
        ns.ui.card(parent, x, y, w, y - bottom)
        return self
    end
    return g
end

local function label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", ns.ui.font(font))
    fs:SetText(text)
    return fs
end

-- ghost: the sidebar's look, no fill until hovered or picked
local function button(parent, text, w, x, y, onClick, ghost)
    local b = ns.ui.Button(parent, text, w, ghost)
    b:SetPoint("TOPLEFT", x, y)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", onClick)
    return b
end

local function check(parent, text, x, y, get, set)
    local cb = ns.ui.Check(parent, text)
    cb:SetPoint("TOPLEFT", x, y - 4)
    cb:SetScript("OnClick", function(self) set(self:GetChecked()); changed() end)
    onRefresh(function() cb:SetChecked(get()) end)
    return cb
end

local function num(v) return type(v) == "function" and v() or v end

-- min/max may be functions, for ranges that depend on the open tab.
local function slider(parent, text, x, y, min, max, get, set, step)
    step = step or 1 -- whole numbers unless a caller wants finer
    local s = ns.ui.Slider(parent, 124) -- 124 + 10 + 44 fits a card's inner width
    s:SetPoint("TOPLEFT", x, y - 20)
    s:SetMinMaxValues(num(min), num(max))
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true) -- wheel = +/-1 for exact values
    label(s, text, "GameFontNormalSmall"):SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 4)
    local syncing
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        if not syncing and v ~= get() then set(v); changed() end
    end)
    s:SetScript("OnMouseWheel", function(_, d) s:SetValue(s:GetValue() + d * step) end)

    -- Typed value: Enter or clicking away applies it (clamped to the slider range), Escape cancels.
    local box = ns.ui.Input(s, 44)
    box:SetPoint("LEFT", s, "RIGHT", 10, 0)
    box:SetMaxLetters(5) -- not SetNumeric: X/Y need a minus sign; tonumber() rejects the rest
    local function apply()
        local v = tonumber(box:GetText())
        if v then
            set(math.max(num(min), math.min(num(max), math.floor(v / step + 0.5) * step)))
            changed()
        end
        box:SetText(tostring(get()))
        box:ClearFocus()
    end
    box:SetScript("OnEnterPressed", apply)
    box:HookScript("OnEditFocusLost", apply)
    box:SetScript("OnEscapePressed", function()
        box:SetText(tostring(get()))
        box:ClearFocus()
    end)

    onRefresh(function()
        -- a dialog's sliders refresh while it is hidden too, against whatever bar is picked;
        -- one that bar has no setting for just rests at its minimum
        local v = tonumber(get()) or num(min)
        syncing = true
        s:SetMinMaxValues(num(min), num(max))
        s:SetValue(v)
        syncing = false
        if not box:HasFocus() then box:SetText(tostring(v)) end
    end)
    return s
end

-- Color swatch + picker. Optional `mode`: { get = fn, set = fn, effective = fn -> r, g, b } for
-- colors that can come from elsewhere (class, bar, power): the swatch and the picker show that
-- color, and picking a new one switches the mode to "custom". Opacity changes keep the mode.
ns.swatches = {}
local function swatch(parent, text, x, y, get, mode)
    local b = CreateFrame("Button", nil, parent)
    ns.swatches[text] = b
    b:SetSize(20, 20)
    b:SetPoint("TOPLEFT", x + 2, y)
    local fillTex = ns.ui.box(b, ns.ui.C.fg, ns.ui.C.ring, 5)
    b.label = label(b, text)
    b.label:SetPoint("LEFT", b, "RIGHT", 6, 0)
    local function shown()
        local c = get()
        if mode then
            local r, g, bl = mode.effective()
            return r, g, bl, c[4]
        end
        return unpack(c)
    end
    b:SetScript("OnClick", function()
        local c = get()
        local old, oldMode = { c[1], c[2], c[3], c[4] }, mode and mode.get()
        local r0, g0, b0 = shown()
        local function apply(r, g, bl, a) c[1], c[2], c[3], c[4] = r, g, bl, a; changed() end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r0, g = g0, b = b0, opacity = c[4], hasOpacity = true,
            swatchFunc = function()
                local r, g, bl = ColorPickerFrame:GetColorRGB()
                if mode then mode.set("custom") end
                apply(r, g, bl, ColorPickerFrame:GetColorAlpha())
            end,
            opacityFunc = function() apply(c[1], c[2], c[3], ColorPickerFrame:GetColorAlpha()) end,
            cancelFunc = function()
                if mode then mode.set(oldMode) end
                apply(unpack(old))
            end,
        })
    end)
    onRefresh(function() fillTex:SetColorTexture(shown()) end)
    return b
end

-- Dropdown over a { {name, value}, ... } list; preview(button, value) decorates each entry and
-- returns its width.
local function dropdown(parent, text, x, y, list, get, set, preview)
    local dd = ns.ui.Dropdown(CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate"))
    dd:SetPoint("TOPLEFT", x, y - 16)
    dd:SetSize(178, 26)
    label(dd, text, "GameFontNormalSmall"):SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 0, 4)
    dd:SetupMenu(function(_, root)
        for _, item in ipairs(type(list) == "function" and list() or list) do
            local radio = root:CreateRadio(item[1], function() return get() == item[2] end,
                function() set(item[2]); changed() end)
            radio:AddInitializer(function(button) return preview(button, item), 20 end)
        end
    end)
    onRefresh(function() dd:GenerateMenu() end)
    return dd
end

-- Menu entry previews sit in a fixed-width column right after the radio tick, and the name
-- starts after that column, so a preview can never cover a name, however wide the menu ends up.
-- Returns the entry width. (Name width falls back to an estimate if it can't be measured yet.)
local function beforeName(button, item, region, slot)
    if button.leftTexture1 then
        region:SetPoint("LEFT", button.leftTexture1, "RIGHT", 4, 0)
    else
        region:SetPoint("LEFT", button, "LEFT", 22, 0)
    end
    button.fontString:SetPoint("LEFT", region, "LEFT", slot + 10, 0)
    local nameW = math.max(button.fontString:GetUnboundedStringWidth(), #item[1] * 7)
    return 22 + slot + 10 + nameW + 12
end

local function textPreview(button, item)
    return 22 + math.max(button.fontString:GetUnboundedStringWidth(), #item[1] * 7) + 16
end

local function texturePreview(button, item)
    local t = button:AttachTexture()
    t:SetSize(90, 12)
    t:SetTexture(item[2])
    t:SetVertexColor(unpack(cur().color))
    return beforeName(button, item, t, 90)
end

-- Menu font strings refuse SetFont, so each font gets a Font object for SetFontObject.
-- Copying the default first keeps a usable font if a file fails to load.
for i, f in ipairs(FONTS) do
    f.object = CreateFont("WolfpackAddonFont" .. i)
    f.object:CopyFontObject(GameFontHighlight)
    f.object:SetFont(f[2], 14, "")
end

for i, f in ipairs(COMBAT_FONTS) do
    f.object = CreateFont("WolfpackAddonCombatFont" .. i)
    f.object:CopyFontObject(GameFontHighlight)
    f.object:SetFont(f[2] ~= "" and f[2] or DEFAULT_DAMAGE_FONT, 16, "OUTLINE")
end

local DAMAGE_YELLOW = { 1, 1, 0 } -- like the game's spell damage numbers

local function combatFontPreview(button, item)
    local fs = button:AttachFontString()
    fs:SetFontObject(item.object)
    fs:SetTextColor(unpack(DAMAGE_YELLOW))
    fs:SetText("123")
    return beforeName(button, item, fs, 56) -- widest: Press Start 2P, 48 px at 16 px
end

local function fontPreview(button, item)
    local fs = button:AttachFontString()
    fs:SetFontObject(item.object)
    fs:SetText("123")
    return beforeName(button, item, fs, 44)
end

local function iconPreview(button, item)
    local t = button:AttachTexture()
    t:SetSize(20, 20)
    t:SetTexture(item[2])
    return beforeName(button, item, t, 20)
end

local function move(i, d)
    local o, j = L().order, i + d
    if o[j] then
        o[i], o[j] = o[j], o[i]
        changed()
    end
end

------------------------------------------------------------------------------------------
-- Profiles (account-wide). Each character starts on its class profile, e.g. "Rogue".
------------------------------------------------------------------------------------------
-- A profile saved before a bar existed keeps its own order, and merge leaves a list it already
-- has alone -- so without this a new bar would never appear for anybody who had played before.
-- Unknown names are dropped at the same time, which is what a removed bar leaves behind.
function ns.repairOrder(layout, default)
    if type(layout) ~= "table" or type(layout.order) ~= "table" then return end
    local seen, kept = {}, {}
    for _, key in ipairs(layout.order) do
        if BARS[key] and not seen[key] then
            seen[key] = true
            kept[#kept + 1] = key
        end
    end
    for _, key in ipairs(default) do
        if not seen[key] then kept[#kept + 1] = key end
    end
    layout.order = kept
end

useProfile = function(name)
    store.profiles[name] = merge(store.profiles[name] or ns.freshProfile(name), DEFAULTS)
    for _, which in ipairs({ "regular", "nameplate" }) do
        ns.repairOrder(store.profiles[name][which], DEFAULTS[which].order)
    end
    store.chars[charKey] = name
    db = store.profiles[name]
    local P = db.colors
    if not P.moved then -- colors that lived on single bars move into the palette
        local pc = db.regular.bars.power.powerColors
        for token, c in pairs(type(pc) == "table" and pc or {}) do
            if P.power[token] and type(c) == "table" then P.power[token] = { unpack(c) } end
        end
        local tc = db.regular.bars.targetcast
        for kind, key in pairs({ harm = "harmColor", heal = "healColor", locked = "lockedColor" }) do
            if type(tc[key]) == "table" then P.cast[kind] = { unpack(tc[key]) } end
        end
        for _, m in ipairs({ "regular", "nameplate" }) do
            local bars = db[m].bars
            bars.power.powerColors = nil
            bars.targetcast.harmColor, bars.targetcast.healColor, bars.targetcast.lockedColor = nil, nil, nil
            for _, b in pairs(bars) do -- a class-colored border is now "same as bar" or your own
                if b.borderMode == "class" then b.borderMode = "bar" end
                if b.resBorderMode == "class" then b.resBorderMode = "bar" end
            end
        end
        P.moved = true
    end
    local ci = db.regular.combatIcon
    if type(ci) == "table" then -- the old in-combat icon becomes your health bar's status icon
        local st = db.regular.bars.health.statusIcon
        st.show, st.style, st.size = ci.show and true or false, ci.style or st.style, ci.size or st.size
        if ci.bar == nil or ci.bar == "health" then -- its spot: x from the middle, or (older) the left edge
            st.point, st.x, st.y = ci.fromCenter and "CENTER" or "LEFT", ci.x or st.x, ci.y or st.y
        end
        db.regular.combatIcon = nil
    end
    for _, m in ipairs({ "regular", "nameplate" }) do
        for _, key in ipairs({ "health", "power", "enemyhealth" }) do
            local b = db[m].bars[key]
            if not b.textsSet then -- the one text it had becomes "current", as it looked
                b.texts.current.size, b.texts.current.color = b.fontSize, { unpack(b.textColor) }
                b.textsSet = true
            end
        end
        local tc = db[m].bars.targetcast
        if not tc.autoSet then
            if tc.colorMode == "custom" then tc.colorMode = "auto" end
            tc.autoSet = true
        end
    end
    if db.regular.bars.health.target then
        db.regular.bars.health.target = false
        db.regular.bars.enemyhealth.show, db.regular.bars.enemyhealth.beside = true, true
    end
    applyCombatFont() -- the font travels with the profile
    place()
    changed()
    ns.profileName = name -- Bar Stack keeps its groups, bars and icons per Wolfpack profile
    local bs = ns.bs
    if bs and bs.db and bs.LoadProfile then
        bs.LoadProfile()
        bs.Apply()
        if bs.RefreshConfig then safe(bs.RefreshConfig) end
    end
end

-- Your profiles plus the ready-made ones you haven't used yet.
local function profileNames()
    local names, seen = {}, {}
    for name in pairs(store.profiles) do
        names[#names + 1] = name
        seen[name] = true
    end
    for _, preset in ipairs(PRESETS) do
        if not seen[preset[1]] then names[#names + 1] = preset[1] end
    end
    table.sort(names)
    return names
end

-- A name nobody is using yet: "Alpha", then "Alpha 2", "Alpha 3"...
local function freeName(base)
    local name, n = base, 2
    while store.profiles[name] do
        name, n = base .. " " .. n, n + 1
    end
    return name
end

-- New profiles start as a copy of the current one; a name already taken gets a number.
local function createProfile(name)
    name = strtrim(name or "")
    if name == "" then return end
    name = freeName(name)
    store.profiles[name] = merge({}, db)
    useProfile(name)
end

-- Characters on the deleted profile fall back to their class profile (recreated if needed).
local function deleteProfile(name)
    store.profiles[name] = nil
    for char, p in pairs(store.chars) do
        if p == name then store.chars[char] = nil end
    end
    useProfile(classProfile)
end

------------------------------------------------------------------------------------------
-- Export / import. Two separate strings:
--  * the addon profile: "WPA1:" + base64(deflate(CBOR{ name, profile, combatFont, barStack })),
--    imported here; barStack is Bar Stack's profile, which has no string of its own
--  * the WoW UI layout: Blizzard's own Edit Mode string, imported in Edit Mode itself, because
--    writing Edit Mode layouts from an addon would get overwritten or taint Edit Mode
------------------------------------------------------------------------------------------
local E = C_EncodingUtil

-- A profile whose name holds a class name belongs to that class, so one string can carry
-- "Alpha Priest", "Alpha Warrior" and the rest, and each character lands on its own.
ns.CLASS_NAMES = { "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage",
    "Warlock", "Druid" }

local function classOfProfile(name)
    local low, best = name:lower(), nil
    for _, cls in ipairs(ns.CLASS_NAMES) do
        if low:find(cls:lower(), 1, true) then best = cls:upper() end
    end
    return best
end

-- `all` packs every profile you have into the one string, instead of only the one in use.
local function exportString(all)
    local data = { name = store.chars[charKey], profile = db, combatFont = db.other.combatFont,
        barStack = ns.bs and ns.bs.profile }
    if all then
        data.profiles, data.classes = {}, {}
        for name, prof in pairs(store.profiles) do
            data.profiles[name] = prof
            local token = classOfProfile(name)
            -- the most specific name wins, so "Alpha Priest" beats a plain "Priest"
            if token and #name > #(data.classes[token] or "") then data.classes[token] = name end
        end
    end
    return "WPA1:" .. E.EncodeBase64(E.CompressString(E.SerializeCBOR(data)))
end

local function editModeString()
    local ok, layout = pcall(function()
        return C_EditMode.ConvertLayoutInfoToString(EditModeManagerFrame:GetActiveLayoutInfo())
    end)
    return ok and type(layout) == "string" and layout or nil
end

-- An imported profile is untrusted: keep only settings DEFAULTS knows, with the same type and
-- sane numbers; the bar order keeps known bars once each and gets missing ones appended.
local MIN_NUMBER = { width = 1, height = 1, size = 1, fontSize = 1, borderSize = 0, gap = 0, spacing = 0 }

local function sanitize(src, template)
    local out = {}
    src = type(src) == "table" and src or {}
    for k, def in pairs(template) do
        local v = src[k]
        if k == "stops" then -- 2 to MAX_STOPS points, each a percent and a color
            out.stops = {}
            for _, stop in ipairs(type(v) == "table" and v or {}) do
                local pos, col = stop and stop.pos, stop and stop.color
                if type(pos) == "number" and pos == pos and pos >= 0 and pos <= 100 and type(col) == "table"
                    and #out.stops < MAX_STOPS then
                    out.stops[#out.stops + 1] = { pos = pos, color = sanitize(col, def[1].color) }
                end
            end
            if #out.stops < 2 then out.stops = sanitize(nil, def) end
        elseif k == "hover" then -- a map: only known elements, only true
            out.hover = {}
            for _, e in ipairs(HOVER_FRAMES) do
                if type(v) == "table" and v[e[1]] == true then out.hover[e[1]] = true end
            end
        elseif k == "list" then -- buff reminders: { name, id, show }
            out.list = {}
            for _, e in ipairs(type(v) == "table" and v or {}) do
                local name = type(e) == "table" and e.name
                if type(name) == "string" and name ~= "" then
                    local dur = tonumber(e.duration) or 18
                    out.list[#out.list + 1] = { name = name:sub(1, 64), id = tonumber(e.id) or 0,
                        show = e.show == true, duration = math.max(1, math.min(600, dur)) }
                end
            end
        elseif k == "slots" then -- a permutation of the totem slots, no gaps, no repeats
            local seen = {}
            out.slots = {}
            for _, n in ipairs(type(v) == "table" and v or {}) do
                if type(n) == "number" and def[n] and not seen[n] then
                    seen[n] = true
                    out.slots[#out.slots + 1] = n
                end
            end
            for i = 1, #def do
                if not seen[i] then out.slots[#out.slots + 1] = i end
            end
        elseif k == "order" then
            local seen = {}
            out.order = {}
            for _, key in ipairs(type(v) == "table" and v or {}) do
                if BARS[key] and not seen[key] then seen[key] = true; out.order[#out.order + 1] = key end
            end
            for _, key in ipairs(def) do
                if not seen[key] then out.order[#out.order + 1] = key end
            end
        elseif type(def) == "table" then
            out[k] = sanitize(v, def)
        elseif type(v) == "number" then
            if v == v and v >= (MIN_NUMBER[k] or -2000) and v <= 2000 then out[k] = v end
        elseif type(v) == type(def) or (k == "radius" and (v == "pill" or v == "round")) then
            out[k] = v
        end
    end
    return out
end

-- The data inside an export string, or nil: shared by Import and the baked default profile.
decodeExport = function(text)
    local b64 = (text or ""):gsub("%s", ""):match("^WPA1:(.+)$") or (text or ""):match("^CPD1:(.+)$")
    if not b64 then return nil end
    local ok, data = pcall(function() return E.DeserializeCBOR(E.DecompressString(E.DecodeBase64(b64))) end)
    if ok and type(data) == "table" and type(data.profile) == "table" then return data end
end

-- A profile as it starts out: the ready-made one of that name, else the built-in layout, and
-- the plain defaults for anything those don't decode or don't set.
function ns.freshProfile(name)
    local from = DEFAULT_PROFILE
    for _, preset in ipairs(PRESETS) do
        if preset[1] == name then from = preset[2] end
    end
    local data = decodeExport(from)
    local mine = data and type(data.profiles) == "table" and data.profiles[name or ""]
    local prof = merge(data and sanitize(mine or data.profile, DEFAULTS) or {}, DEFAULTS)
    for _, f in ipairs(COMBAT_FONTS) do -- strings from before the font moved into the profile
        if data and data.combatFont == f[2] and f[2] ~= "" then prof.other.combatFont = f[2] end
    end
    return prof
end

-- A fresh account (or this beta, which forgets everything) starts from the bundle baked into
-- the addon: every profile in it, and which class each one belongs to.
seedFromBaked = function()
    if next(store.profiles) then return end -- there is already something here
    local data = decodeExport(DEFAULT_PROFILE)
    if not data or type(data.profiles) ~= "table" then return end
    for pname, prof in pairs(data.profiles) do
        if type(pname) == "string" and pname ~= "" and type(prof) == "table" then
            store.profiles[pname] = sanitize(prof, DEFAULTS)
        end
    end
    if type(data.classes) == "table" then
        for token, pname in pairs(data.classes) do
            if store.profiles[pname] then store.classProfiles[token] = pname end
        end
    end
end

-- Returns the new profile's name (and the Edit Mode layout older combined strings carried), or
-- nil and an error.
local function importString(text)
    text = (text or ""):gsub("%s", "")
    local b64 = text:match("^WPA1:(.+)$") or text:match("^CPD1:(.+)$") -- CPD1: was the old name
    if not b64 then
        local ok, layout = pcall(C_EditMode.ConvertStringToLayoutInfo, text)
        if text ~= "" and ok and layout then
            return nil, "That's a WoW UI layout string. Paste it in Edit Mode instead: open Edit Mode, "
                .. "then Layout dropdown, Import."
        end
        return nil, "That's not a Wolfpack Addon string (those start with WPA1:)."
    end
    local ok, data = pcall(function() return E.DeserializeCBOR(E.DecompressString(E.DecodeBase64(b64))) end)
    if not ok or type(data) ~= "table" or type(data.profile) ~= "table" then
        return nil, "The string is damaged or incomplete. Copy it again in full."
    end
    -- A bundle: every profile in it lands under its own name, replacing one of the same name,
    -- and each class is remembered so its characters start on the right one.
    if type(data.profiles) == "table" then
        local first, count = nil, 0
        for pname, prof in pairs(data.profiles) do
            local clean = type(pname) == "string" and strtrim(pname):sub(1, 32) or ""
            if clean ~= "" and type(prof) == "table" then
                store.profiles[clean] = sanitize(prof, DEFAULTS)
                first, count = first or clean, count + 1
            end
        end
        store.classProfiles = {}
        if type(data.classes) == "table" then
            for token, pname in pairs(data.classes) do
                if type(pname) == "string" and store.profiles[pname] then
                    store.classProfiles[token] = pname
                end
            end
        end
        if count == 0 then return nil, "The string holds no profiles. Copy it again in full." end
        local mine = store.classProfiles[class or ""]
        if not (mine and store.profiles[mine]) then mine = data.name end
        useProfile(store.profiles[mine or ""] and mine or first)
        ns.importBarStack(data)
        return store.chars[charKey], nil, count
    end
    local base = type(data.name) == "string" and strtrim(data.name):sub(1, 32) or ""
    if base == "" then base = "Imported" end
    local name = freeName(base)
    store.profiles[name] = sanitize(data.profile, DEFAULTS)
    for _, f in ipairs(COMBAT_FONTS) do -- older strings carried the font outside the profile
        if data.combatFont == f[2] and f[2] ~= "" then store.profiles[name].other.combatFont = f[2] end
    end
    useProfile(name)
    ns.importBarStack(data)
    return name, type(data.editMode) == "string" and data.editMode or nil
end
-- Bar Stack's profile rides along: it goes to the profile just switched to, for this spec
function ns.importBarStack(data)
    if type(data.barStack) == "table" and ns.bs and ns.bs.ImportProfile then
        pcall(ns.bs.ImportProfile, data.barStack)
    end
end
ns.exportString, ns.editModeString, ns.importString = exportString, editModeString, importString
ns.seedFromBaked = function() return seedFromBaked() end
ns.useProfile = useProfile

-- Another profile's settings (Bar Stack's too) replace the current one's; the name stays.
function ns.copyProfile(from)
    local into = store.chars[charKey]
    if from == into then return end
    wipe(db)
    merge(db, store.profiles[from] or ns.freshProfile(from))
    if ns.bs and ns.bs.CopyFrom then pcall(ns.bs.CopyFrom, from) end
    useProfile(into)
end

StaticPopupDialogs.WOLFPACKADDON_COPY = {
    text = "Copy profile \"%s\" onto \"%s\"?\nIts current settings are replaced.",
    button1 = YES, button2 = NO,
    OnAccept = function(_, from) ns.copyProfile(from) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs.WOLFPACKADDON_RESET = {
    text = "Reset profile \"%s\" to its defaults?",
    button1 = YES, button2 = NO,
    OnAccept = function()
        wipe(db)
        merge(db, ns.freshProfile(store.chars[charKey]))
        place()
        changed()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs.WOLFPACKADDON_DELETE = {
    text = "Delete Wolfpack Addon profile \"%s\"?",
    button1 = YES, button2 = NO,
    OnAccept = function(_, name) deleteProfile(name) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local openStops -- the gradient points dialog, defined below


function ns.textArea(parent, y, h) -- on the namespace: this chunk is at Lua's 200-local ceiling
    local area = CreateFrame("Frame", nil, parent)
    area:SetPoint("TOPLEFT", 14, y)
    area:SetPoint("TOPRIGHT", -14, y)
    area:SetHeight(h)
    ns.ui.box(area, ns.ui.C.input, ns.ui.C.border, 6)
    local sf = ns.ui.Scroll(CreateFrame("ScrollFrame", nil, area, "UIPanelScrollFrameTemplate"))
    sf:SetPoint("TOPLEFT", 8, -6)
    sf:SetPoint("BOTTOMRIGHT", -24, 6)
    local box = CreateFrame("EditBox", nil, sf)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetMaxLetters(0)
    box:SetFontObject(ns.ui.SMALL)
    box:SetWidth(470)
    box:SetScript("OnEscapePressed", function() box:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function() box:HighlightText() end) -- click, Ctrl+C
    sf:SetScrollChild(box)
    area.box = box
    return area
end

local function openIO(mode)
    local f = ns.ioFrame
    if not f then
        f = ns.ui.Window("WolfpackAddonIO", 540, 410, "")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f.title = f.TitleText
        f.label1 = label(f, "", "GameFontNormalSmall")
        f.label1:SetPoint("TOPLEFT", 16, -50)
        f.all = ns.ui.Check(f, "All profiles in one string")
        f.all:SetPoint("TOPLEFT", 340, -48)
        f.all:SetScript("OnClick", function(self)
            f.area1.box:SetText(exportString(self:GetChecked()))
            f.area1.box:SetFocus()
        end)
        f.area1 = ns.textArea(f, -68, 104)
        f.label2 = label(f, "2. WoW UI layout (Edit Mode). Import it in Edit Mode: Layout dropdown, Import.",
            "GameFontNormalSmall")
        f.label2:SetPoint("TOPLEFT", 16, -184)
        f.area2 = ns.textArea(f, -202, 104)
        f.note = label(f, "", "GameFontDisableSmall")
        f.note:SetPoint("TOPLEFT", 16, -318)
        f.note:SetWidth(505)
        f.note:SetJustifyH("LEFT")
        f.import = ns.ui.Button(f, "Import", 100)
        f.import:SetPoint("BOTTOMRIGHT", -16, 14)
        f.import:SetScript("OnClick", function()
            local name, extra, count = importString(f.area1.box:GetText())
            if not name then
                f.note:SetText("|cffff5555" .. extra .. "|r")
            else
                f.area1.box:SetText("")
                f.note:SetText((count and ("Imported " .. count .. " profiles; this character is on \""
                        .. tostring(name) .. "\". Others start on the one named after their class.")
                    or ("Imported as profile \"" .. name .. "\" and switched to it."))
                    .. (extra and " This older string also held a WoW UI layout: it's in the box below, "
                        .. "for Edit Mode's Import." or ""))
                f.area2:SetShown(extra ~= nil)
                f.label2:SetShown(extra ~= nil)
                if extra then f.area2.box:SetText(extra) end
            end
        end)
        ns.ioFrame = f
    end
    local export = mode == "export"
    f.title:SetText(export and "Export" or "Import profile")
    f.import:SetShown(not export)
    f.all:SetShown(export)
    f.area2:SetShown(export)
    f.label2:SetShown(export)
    if export then
        f.label1:SetText("1. Addon profile. Import it on the Profiles page.")
        f.area1.box:SetText(exportString(f.all:GetChecked()))
        f.area2.box:SetText(editModeString() or "(The WoW UI layout isn't available right now.)")
        f.note:SetText("Click a box, then Ctrl+C. Keep the profile string somewhere safe: the beta forgets "
            .. "addon settings when the game restarts, and it brings them back. Tick \"All profiles\" to "
            .. "pack every one you have into the same string -- name them after a class, like \"Alpha "
            .. "Priest\", and each character starts on its own.")
        f.area1.box:SetFocus()
    else
        f.label1:SetText("Paste an addon profile string (starts with WPA1:), then click Import.")
        f.area1.box:SetText("")
        f.note:SetText("A single profile becomes a new one. A string with several replaces the profiles "
            .. "of the same name. WoW UI layout strings go into Edit Mode's own Import.")
        f.area1.box:SetFocus()
    end
    f:Show()
end

-- Gradient points dialog: percent + color per point, for the bar picked in the options.
local stopsFrame
function openStops()
    local f = stopsFrame
    if not f then
        f = ns.ui.Window("WolfpackAddonStops", 340, 350, "Gradient points")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f.title = f.TitleText
        label(f, "Percent across the bar, and the color there.", "GameFontDisableSmall")
            :SetPoint("TOPLEFT", 16, -50)
        f.rows = {}
        for i = 1, MAX_STOPS do
            local y = -70 - (i - 1) * 28
            local row = CreateFrame("Frame", nil, f)
            row:SetPoint("TOPLEFT", 16, y)
            row:SetSize(300, 24)
            local box = ns.ui.Input(row, 44)
            box:SetPoint("TOPLEFT", 0, 0)
            box:SetMaxLetters(3)
            local function applyPos()
                local v = tonumber(box:GetText())
                local stop = cur().stops[i]
                if v and stop then stop.pos = math.max(0, math.min(100, math.floor(v))) end
                box:SetText(stop and tostring(stop.pos) or "")
                box:ClearFocus()
                changed()
            end
            box:SetScript("OnEnterPressed", applyPos)
            box:HookScript("OnEditFocusLost", applyPos)
            label(row, "%", "GameFontHighlight"):SetPoint("LEFT", box, "RIGHT", 4, 0)
            local spare = { 1, 1, 1, 1 } -- rows past the last point still refresh
            swatch(row, "Point " .. i, 62, 0, function() return cur().stops[i] and cur().stops[i].color or spare end)
            local del = button(row, "Delete", 64, 210, 0, function()
                table.remove(cur().stops, i)
                changed()
            end)
            row.box, row.del = box, del
            f.rows[i] = row
        end
        f.add = button(f, "Add point", 100, 16, -74 - MAX_STOPS * 28, function()
            local stops = cur().stops
            local last = stops[#stops]
            tinsert(stops, { pos = last and last.pos or 100, color = { 1, 1, 1, 1 } })
            changed()
        end)
        onRefresh(function()
            if not f:IsShown() then return end
            local stops = cur().stops
            for i, row in ipairs(f.rows) do
                row:SetShown(stops[i] ~= nil)
                if stops[i] then
                    if not row.box:HasFocus() then row.box:SetText(tostring(stops[i].pos)) end
                    row.del:SetShown(#stops > 2)
                end
            end
            f.add:SetShown(#stops < MAX_STOPS)
            f.title:SetText("Gradient points: " .. BARS[selected].label)
        end)
        stopsFrame = f
    end
    f:Show()
    changed()
end

function ns.foldColumns(page, COL, TOP)
    local cards, low = ns.cards and ns.cards[page] or {}, TOP
    for _, c in ipairs(cards) do
        if c.x < COL[3] then low = math.min(low, c.bottom) end
    end
    local dx, dy = COL[1] - COL[3], low - 20 - TOP
    local need = -low
    for _, c in ipairs(cards) do
        need = math.max(need, -(c.x < COL[3] and c.bottom or c.bottom + dy))
    end
    page.need = need
    if dy == 0 then return end
    local items = { page:GetChildren() }
    for _, r in ipairs({ page:GetRegions() }) do items[#items + 1] = r end
    for _, r in ipairs(items) do
        local point, rel, relPoint, x, y = r:GetPoint(1)
        if r:GetNumPoints() == 1 and point == "TOPLEFT" and (rel == nil or rel == page) and relPoint == "TOPLEFT"
            and x and x >= COL[3] then
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", page, "TOPLEFT", x + dx, y + dy)
        end
    end
end

-- the windows beside the options: one at a time; clicking its button again closes it
function ns.toggleDialog(d)
    local show = not d:IsShown()
    for _, o in ipairs({ ns.resDialog, ns.tagDialog, ns.auraDialog, ns.textDialog, ns.iconDialog,
        ns.statusDialog }) do o:Hide() end
    d:SetShown(show)
end

local function buildConfig()
    cfg = ns.ui.Window("WolfpackAddonConfig", 680, 700, "Wolfpack", 52)
    cfg.TitleText:SetFontObject(ns.ui.TITLE)
    cfg:HookScript("OnShow", function() ns.configOpen = true; changed() end)
    cfg:HookScript("OnHide", function() ns.configOpen = false; changed() end)

    -- Pages to the right of the sidebar, in a scroll area under the title row. A page keeps the
    -- window's coordinates (its cards start 100 down), so it sits 90 above the area's top.
    local scroller = ns.ui.Scroll(CreateFrame("ScrollFrame", nil, cfg, "UIPanelScrollFrameTemplate"))
    scroller:SetPoint("TOPLEFT", 143, -90)
    scroller:SetPoint("BOTTOMRIGHT", -22, 8)
    local content = CreateFrame("Frame", nil, scroller)
    content:SetSize(515, 1)
    scroller:SetScrollChild(content)
    ns.scroller, ns.content = scroller, content
    -- Four columns of boxes; a box's rows are stacked by g:row(height).
    local COL, TOP = { 16, 226, 436, 646 }, -100
    local ROW, SLIDER, DROP, SWATCH, BUTTON = 24, 46, 50, 26, 28

    -- Header: the profile in use (account-wide, holds every page); a click opens its page
    local inUse = button(cfg, "", 240, 150, -14, function() section, mode = "profile", "regular"; changed() end, true)
    onRefresh(function() inUse:SetText("Profile: |cffffffff" .. tostring(store.chars[charKey]) .. "|r") end)

    -- Profiles page: everything about profiles, each job in its own card
    local profilePage = CreateFrame("Frame", nil, content)
    profilePage:SetPoint("TOPLEFT", content, "TOPLEFT", -9, 90)
    profilePage:SetSize(524, 700)
    local function note(g, text, h)
        local n = label(profilePage, text, "GameFontDisableSmall")
        n:SetPoint("TOPLEFT", g.x, g:row(h))
        n:SetWidth(178)
        n:SetJustifyH("LEFT")
    end
    local function profileMenu(g, pick, others) -- others: leave out the profile in use
        local dd = ns.ui.Dropdown(CreateFrame("DropdownButton", nil, profilePage, "WowStyle1DropdownTemplate"))
        dd:SetPoint("TOPLEFT", g.x, g:row(32))
        dd:SetSize(178, 26)
        dd:SetupMenu(function(_, root)
            for _, name in ipairs(profileNames()) do
                if not (others and name == store.chars[charKey]) then
                    root:CreateRadio(name, function() return not others and name == store.chars[charKey] end,
                        function() pick(name) end)
                end
            end
        end)
        onRefresh(function() dd:GenerateMenu() end)
        return dd
    end
    local function danger(b)
        b:SetNormalFontObject(ns.ui.DANGER)
        b:SetHighlightFontObject(ns.ui.DANGER)
        return b
    end

    local use = group(profilePage, COL[1], TOP, 202, "In use")
    profileMenu(use, useProfile)
    note(use, "Every page of this window is saved to it, Bar Stack included. Any character can use it.", 46)
    danger(button(profilePage, "Delete profile", 178, use.x, use:row(BUTTON), function()
        local name = store.chars[charKey]
        StaticPopup_Show("WOLFPACKADDON_DELETE", name, nil, name)
    end))
    note(use, "Characters on it go back to their class profile.", 22)
    use:close()

    local copy = group(profilePage, COL[1], use.cursor - 20, 202, "Copy settings")
    ns.copyFromMenu = profileMenu(copy, function(name)
        StaticPopup_Show("WOLFPACKADDON_COPY", name, store.chars[charKey], name)
    end, true)
    ns.copyFromMenu:SetDefaultText("Copy from...")
    note(copy, "Another profile's settings replace this one's, Bar Stack included. Asks first.", 34)
    copy:close()

    local new = group(profilePage, COL[2], TOP, 202, "New profile")
    local nameBox = ns.ui.Input(profilePage, 178)
    nameBox:SetPoint("TOPLEFT", new.x, new:row(32))
    nameBox:SetMaxLetters(32)
    local hint = label(nameBox, "Name", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 8, 0)
    nameBox:HookScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
    local function create()
        createProfile(nameBox:GetText())
        nameBox:SetText("")
        nameBox:ClearFocus()
    end
    nameBox:SetScript("OnEnterPressed", create)
    nameBox:SetScript("OnEscapePressed", function() nameBox:ClearFocus() end)
    button(profilePage, "Create", 178, new.x, new:row(BUTTON), create)
    note(new, "Starts as a copy of the profile in use, and switches to it.", 34)
    new:close()

    local share = group(profilePage, COL[2], new.cursor - 20, 202, "Share or back up")
    local at = share:row(BUTTON)
    button(profilePage, "Export", 87, share.x, at, function() openIO("export") end)
    button(profilePage, "Import", 87, share.x + 91, at, function() openIO("import") end)
    note(share, "One text string holds the profile. Keep a copy: the beta forgets addon settings on restart.", 46)
    share:close()

    local reset = group(profilePage, COL[2], share.cursor - 20, 202, "Start over")
    danger(button(profilePage, "Reset to defaults", 178, reset.x, reset:row(BUTTON), function()
        StaticPopup_Show("WOLFPACKADDON_RESET", store.chars[charKey])
    end))
    note(reset, "Puts this profile back to how it started. Asks first.", 34)
    reset:close()

    -- Sidebar: what dresses the screen, then your classes
    local y = -64
    local function shelf(title)
        label(cfg, title:upper(), "GameFontDisableSmall"):SetPoint("TOPLEFT", 22, y)
        y = y - 18
    end
    local function entry(key, text, m)
        local b = button(cfg, text, 122, 12, y, function()
            section, mode = key, m or "regular"
            changed()
        end, true)
        onRefresh(function() if section == key then b:LockHighlight() else b:UnlockHighlight() end end)
        y = y - 28
        return b
    end

    entry("profile", "Profiles")
    entry("colors", "Colors")
    y = y - 12
    shelf("Interface")
    for _, e in ipairs({ { "combat", "Combat Display" }, { "nameplates", "Nameplates", "nameplate" },
        { "buffs", "Buff check" }, { "other", "Other" }, { "barstack", "Bar Stack" } }) do
        entry(e[1], e[2], e[3])
    end
    y = y - 12
    shelf("Classes")
    for _, e in ipairs(ns.CLASS_SECTIONS) do
        local b = entry(e[1], e[2])
        if e[3] == class then -- your own class carries a quiet "you"
            label(b, "you", "GameFontDisableSmall"):SetPoint("RIGHT", -10, 0)
        end
    end

    ns.sidebarBottom = y
    local divider = cfg:CreateTexture(nil, "ARTWORK")
    ns.ui.paint(divider, ns.ui.C.border)
    divider:SetPoint("TOPLEFT", 142, -53)
    divider:SetPoint("BOTTOMLEFT", 142, 1)
    divider:SetWidth(1)

    local barsPage = CreateFrame("Frame", nil, content)
    barsPage:SetPoint("TOPLEFT", content, "TOPLEFT", -9, 90)
    barsPage:SetSize(524, 700)
    local questPage = CreateFrame("Frame", nil, content)
    questPage:SetAllPoints(barsPage)
    local otherPage = CreateFrame("Frame", nil, content)
    otherPage:SetAllPoints(barsPage)
    local buffPage = CreateFrame("Frame", nil, content)
    buffPage:SetAllPoints(barsPage)
    local magePage = CreateFrame("Frame", nil, content)
    magePage:SetAllPoints(barsPage)
    local hunterPage = CreateFrame("Frame", nil, content)
    hunterPage:SetAllPoints(barsPage)
    local lockPage = CreateFrame("Frame", nil, content)
    lockPage:SetAllPoints(barsPage)
    local roguePage = CreateFrame("Frame", nil, content)
    roguePage:SetAllPoints(barsPage)
    local shamanPage = CreateFrame("Frame", nil, content)
    shamanPage:SetAllPoints(barsPage)
    local colorPage = CreateFrame("Frame", nil, content)
    colorPage:SetAllPoints(barsPage)
    -- Bar Stack builds its own editor (BarStack/Config.lua) into this page, under the title
    local bsPage = CreateFrame("Frame", nil, content)
    bsPage:SetAllPoints(barsPage)
    bsPage.need = 100 + ns.ui.BS_H
    ns.pages = { combat = barsPage, nameplates = questPage, buffs = buffPage, mage = magePage,
        hunter = hunterPage, warlock = lockPage, rogue = roguePage, shaman = shamanPage,
        other = otherPage, profile = profilePage, colors = colorPage }

    local title = label(cfg, "Combat Display", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 150, -72)
    local tabs = {}
    for i, t in ipairs({ { "bars", "Bars" }, { "quest", "Quest mobs" } }) do
        tabs[i] = button(cfg, t[2], 110, 150 + (i - 1) * 114, -66, function() sub = t[1]; changed() end)
        onRefresh(function() if sub == t[1] then tabs[i]:LockHighlight() else tabs[i]:UnlockHighlight() end end)
    end
    onRefresh(function()
        local np = section == "nameplates"
        -- the tab row stands where the title would: the tabs are the heading on those pages
        title:SetShown(not np)
        title:SetText(section == "other" and "Other"
            or section == "profile" and "Profiles"
            or section == "colors" and "Colors"
            or section == "buffs" and "Buff check"
            or section == "mage" and "Mage: food and water"
            or section == "hunter" and "Hunter: ammo and pet"
            or section == "warlock" and "Warlock: soul shards"
            or section == "rogue" and "Rogue: weapon poisons"
            or section == "shaman" and "Shaman: weapon imbues"
            or section == "barstack" and "Bar Stack"
            or "Combat Display")
        for _, t in ipairs(tabs) do t:SetShown(np) end
        barsPage:SetShown(section == "combat" or (np and sub == "bars"))
        questPage:SetShown(np and sub == "quest")
        otherPage:SetShown(section == "other")
        buffPage:SetShown(section == "buffs")
        magePage:SetShown(section == "mage")
        hunterPage:SetShown(section == "hunter")
        lockPage:SetShown(section == "warlock")
        roguePage:SetShown(section == "rogue")
        shamanPage:SetShown(section == "shaman")
        bsPage:SetShown(section == "barstack")
        profilePage:SetShown(section == "profile")
        colorPage:SetShown(section == "colors")
        local page = section == "barstack" and bsPage or ns.pages[section]
        if np and sub == "quest" then page = questPage end
        if page and page.need then content:SetHeight(math.max(1, page.need - 90 + 16)) end
        if section ~= ns.shownSection then -- a new page starts at its top
            ns.shownSection = section
            scroller:SetVerticalScroll(0)
        end
        if section == "barstack" and ns.bs then safe(ns.bs.ShowConfig, bsPage) end
    end)

    local tabNote = label(barsPage, "", "GameFontDisableSmall")
    onRefresh(function()
        tabNote:ClearAllPoints()
        if section == "nameplates" then tabNote:SetPoint("LEFT", tabs[2], "RIGHT", 14, 0)
        else tabNote:SetPoint("LEFT", title, "RIGHT", 14, -1) end
        tabNote:SetText(mode == "regular" and "Health, power and combo bars on your screen."
            or "Bars under your target's nameplate. Needs enemy nameplates on (V key).")
    end)

    -- Bars page, column 1: which bars, and where the group sits
    local bars = group(barsPage, COL[1], TOP, 202, "Bars, top to bottom")
    for i = 1, #db.regular.order do
        local y = bars:row(ROW)
        local sel = button(barsPage, "", 100, bars.x, y, function() selected = L().order[i]; changed() end, true)
        button(barsPage, "Up", 34, bars.x + 104, y, function() move(i, -1) end):SetHeight(22)
        button(barsPage, "Down", 40, bars.x + 140, y, function() move(i, 1) end):SetHeight(22)
        sel:SetHeight(22)
        onRefresh(function()
            local key = L().order[i]
            sel:SetText(BARS[key].label)
            if key == selected then sel:LockHighlight() else sel:UnlockHighlight() end
        end)
    end
    slider(barsPage, "Gap between bars", bars.x, bars:row(SLIDER), 0, 30,
        function() return L().gap end, function(v) L().gap = v end)
    bars:close()

    local grp = group(barsPage, COL[1], bars.cursor - 20, 202, "Group position")
    local groupNote = label(barsPage, "", "GameFontDisableSmall")
    groupNote:SetPoint("TOPLEFT", grp.x, grp:row(16))
    onRefresh(function()
        groupNote:SetText((L().grow == "up" and "bottom-center" or "top-center")
            .. (mode == "regular" and ", from the screen center" or ", from under the nameplate"))
    end)
    local grow = button(barsPage, "", 186, grp.x, grp:row(BUTTON), function()
        L().grow = L().grow == "up" and "down" or "up"
        place()
        changed()
    end)
    onRefresh(function() grow:SetText("Grows: " .. (L().grow == "up" and "Upwards" or "Downwards")) end)
    local function xr() return mode == "regular" and math.floor(UIParent:GetWidth() / 2) or 200 end
    local function yr() return mode == "regular" and math.floor(UIParent:GetHeight() / 2) or 200 end
    slider(barsPage, "X (left / right)", grp.x, grp:row(SLIDER), function() return -xr() end, xr,
        function() return L().x end, function(v) L().x = v; place() end)
    slider(barsPage, "Y (down / up)", grp.x, grp:row(SLIDER), function() return -yr() end, yr,
        function() return L().y end, function(v) L().y = v; place() end)
    local lock = button(barsPage, "", 96, grp.x, grp:row(BUTTON), function() db.locked = not db.locked; changed() end)
    onRefresh(function()
        lock:SetShown(mode == "regular")
        lock:SetText(db.locked and "Unlock" or "Lock")
    end)
    grp:close()
    label(barsPage, "Mouse wheel on a slider changes it by 1.", "GameFontDisableSmall")
        :SetPoint("TOPLEFT", grp.x, grp.cursor - 24)

    -- Column 2: the selected bar's size and spacing
    local function selFrame() return (mode == "regular" and frames or plateFrames)[selected] end
    local size = group(barsPage, COL[2], TOP, 202, "")
    onRefresh(function()
        local shown = selFrame():IsShown()
        if selected == "swing" then -- the timer draws in a row per weapon, never in its own frame
            for _, row in ipairs(swingFrames[mode]) do shown = shown or row:IsShown() end
        end
        size.title:SetText(BARS[selected].label .. (shown and "" or " |cff888888(hidden)|r"))
    end)
    check(barsPage, "Show", size.x, size:row(ROW), function() return cur().show end, function(v) cur().show = v end)
    local widthSlider = slider(barsPage, "Width", size.x, size:row(SLIDER), 10, 600,
        function() return cur().width end, function(v) cur().width = v end)
    local heightSlider = slider(barsPage, "Height", size.x, size:row(SLIDER), 2, 100,
        function() return cur().height end, function(v) cur().height = v end)
    slider(barsPage, "Extra space above", size.x, size:row(SLIDER), 0, 60,
        function() return cur().padTop end, function(v) cur().padTop = v end)
    slider(barsPage, "Extra space below", size.x, size:row(SLIDER), 0, 60,
        function() return cur().padBottom end, function(v) cur().padBottom = v end)
    slider(barsPage, "Offset X", size.x, size:row(SLIDER), -300, 300, function() return cur().x end, function(v) cur().x = v end)
    slider(barsPage, "Offset Y", size.x, size:row(SLIDER), -300, 300, function() return cur().y end, function(v) cur().y = v end)
    size:close()

    local only = group(barsPage, COL[2], size.cursor - 20, 202, "Just for this bar")
    local beside = check(barsPage, "Beside your health", only.x, only:row(ROW),
        function() return cur().beside end, function(v) cur().beside = v end)
    -- target of target and your pet: in the stack, or hung on enemy health / your health
    local SITS = {
        tothealth = { { "In the stack", "stack" }, { "Below enemy health", "below" }, { "Right of enemy health", "right" } },
        pethealth = { { "In the stack", "stack" }, { "Below your health", "below" }, { "Left of your health", "left" },
            { "Right of your health", "right" } },
    }
    local sits = dropdown(barsPage, "Sits", only.x, only:row(0), function() return SITS[selected] or {} end,
        function() return cur().anchor end, function(v) cur().anchor = v end, textPreview)
    ns.sitsMenu = sits
    -- target of target: its name at a click (the rest of it is in the Level and name window)
    local totName = check(barsPage, "Show name", only.x, only:row(0) - ROW - 2 * BUTTON,
        function() return cur().tagName end, function(v) cur().tagName = v end)
    local resCheck = check(barsPage, "Show its resource", only.x, only:row(0),
        function() return cur().resource end, function(v) cur().resource = v end)
    local resButton = button(barsPage, "Resource settings", 186, only.x, only:row(0) - ROW, function()
        ns.toggleDialog(ns.resDialog)
    end)
    local tagButton = button(barsPage, "Level and name", 186, only.x, only:row(0) - ROW - BUTTON, function()
        ns.toggleDialog(ns.tagDialog)
    end)
    local iconButton = button(barsPage, "PvP flag", 186, only.x, only:row(0) - ROW - 3 * BUTTON,
        function() ns.toggleDialog(ns.iconDialog) end)
    -- your health: under the incoming heals rows
    local statusButton = button(barsPage, "Status and PvP icons", 186, only.x, only:row(0) - ROW - BUTTON,
        function() ns.toggleDialog(ns.statusDialog) end)
    local auraButton = button(barsPage, "Buffs and debuffs", 186, only.x, only:row(0) - ROW - 2 * BUTTON, function()
        ns.toggleDialog(ns.auraDialog)
    end)
    local swingChecks = {}
    for i, kind in ipairs(SWING_TYPES) do
        swingChecks[i] = check(barsPage, kind[2], only.x, only:row(0) - (i - 1) * ROW,
            function() return cur()[kind[1]] end, function(v) cur()[kind[1]] = v end)
    end
    -- Totems: one row per segment, in the order they appear, each with its element's color.
    local totemRows = {}
    local function moveTotem(i, d)
        local s, j = cur().slots, i + d
        if not s then return end -- another bar is selected; these rows are hidden
        if s[j] then
            s[i], s[j] = s[j], s[i]
            changed()
        end
    end
    for i = 1, #TOTEM_SLOTS do
        local y = only:row(0) - (i - 1) * ROW
        local sw = swatch(barsPage, "Totem " .. i, only.x, y, function()
            local c = cur()
            return c.slots and c.slotColors[c.slots[i]] or { 0, 0, 0, 1 } -- another bar is selected
        end)
        local up = button(barsPage, "Up", 34, only.x + 106, y, function() moveTotem(i, -1) end)
        local down = button(barsPage, "Down", 44, only.x + 142, y, function() moveTotem(i, 1) end)
        totemRows[i] = { sw, up, down }
        onRefresh(function()
            if cur().slots then sw.label:SetText(TOTEM_SLOTS[cur().slots[i]]) end
        end)
    end
    -- Health and power each get a prediction overlay, on the same rows as the totem list
    local healCheck = check(barsPage, "Show incoming heals", only.x, only:row(0), 
        function() return cur().heal end, function(v) cur().heal = v end)
    local healColor = swatch(barsPage, "Heal color", only.x, only:row(0) - ROW,
        function() return cur().healColor or { 0, 0, 0, 1 } end)
    local costCheck = check(barsPage, "Show the cast's cost", only.x, only:row(0),
        function() return cur().cost end, function(v) cur().cost = v end)
    local costColor = swatch(barsPage, "Cost color", only.x, only:row(0) - ROW,
        function() return cur().costColor or { 0, 0, 0, 1 } end)
    local castIcon = check(barsPage, "Show spell icon", only.x, only:row(ROW),
        function() return cur().icon end, function(v) cur().icon = v end)
    local castSide = button(barsPage, "", 186, only.x, only:row(BUTTON), function()
        cur().iconSide = cur().iconSide == "right" and "left" or "right"
        changed()
    end)
    local onlyNote = label(barsPage, "", "GameFontDisableSmall")
    onlyNote:SetPoint("TOPLEFT", only.x, only:row(16))
    onRefresh(function()
        beside:SetShown(selected == "enemyhealth" and mode == "regular")
        resCheck:SetShown(selected == "enemyhealth")
        local resOn = selected == "enemyhealth" and cur().resource or false
        resButton:SetShown(resOn)
        if not (resOn and (section == "combat" or section == "nameplates")) then ns.resDialog:Hide() end
        local ehOn = selected == "enemyhealth" and (section == "combat" or section == "nameplates")
        tagButton:SetShown(selected == "enemyhealth" or selected == "tothealth")
        auraButton:SetShown(selected == "enemyhealth" or selected == "health")
        iconButton:SetShown(selected == "enemyhealth")
        if not ehOn then ns.iconDialog:Hide() end
        if not ((selected == "enemyhealth" or selected == "tothealth") and (section == "combat" or section == "nameplates")) then
            ns.tagDialog:Hide()
        end
        if not (ns.AURA_BARS[selected] and (section == "combat" or section == "nameplates")) then
            ns.auraDialog:Hide()
        end
        statusButton:SetShown(selected == "health")
        if not (selected == "health" and (section == "combat" or section == "nameplates")) then
            ns.statusDialog:Hide()
        end
        -- beside your health it takes half your health bar's width and all of its height
        local fixed = selected == "enemyhealth" and mode == "regular" and cur().beside or false
        -- hung: below takes the host's width, beside it the host's height
        local hungOn = SITS[selected] and mode == "regular" and cur().anchor or "stack"
        sits:SetShown(SITS[selected] ~= nil and mode == "regular")
        totName:SetShown(selected == "tothealth")
        widthSlider:SetShown(not fixed and hungOn ~= "below")
        heightSlider:SetShown(not fixed and (hungOn == "stack" or hungOn == "below"))
        healCheck:SetShown(selected == "health")
        healColor:SetShown(selected == "health")
        costCheck:SetShown(selected == "power")
        costColor:SetShown(selected == "power")
        for _, w in ipairs(swingChecks) do w:SetShown(selected == "swing") end
        for _, row in ipairs(totemRows) do
            for _, w in ipairs(row) do w:SetShown(selected == "totems") end
        end
        castIcon:SetShown(selected == "castbar" or selected == "targetcast")
        castSide:SetShown((selected == "castbar" or selected == "targetcast")
            and cur().icon or false)
        castSide:SetText("Icon side: " .. (cur().iconSide == "right" and "Right" or "Left"))
        local none = not (selected == "castbar" or selected == "swing" or selected == "power"
            or selected == "health" or selected == "targetcast" or selected == "enemyhealth")
        if selected == "range" then
            onlyNote:SetText("Asks your own spells whether they would reach. The whole bar takes "
                .. "the color of where your target stands, and says so: in melee, in the gap "
                .. "nothing covers, in range, or too far.")
        elseif selected == "enemyhealth" then
            onlyNote:SetText("") -- the resource sliders stand where this note would
        elseif selected == "targetcast" then
            onlyNote:SetText("What your target is casting. With Bar color \"By kind of cast\" it takes "
                .. "the color of the kind, from the Colors page: one you cannot stop, a heal, or "
                .. "anything else. Whether it can "
                .. "be stopped the game tells us outright; whether it heals is matched by name, "
                .. "from the list of heals a mob actually casts.")
        elseif selected == "flight" then
            onlyNote:SetText("Shows only while a griffin has you. Nothing in the game will say how "
                .. "long a route takes, so the first time you fly one it is timed and written "
                .. "down; every ride after that counts down. Routes are remembered for the whole "
                .. "account.")
        else
            onlyNote:SetText(selected ~= "totems" and none and "Nothing extra for this one." or "")
        end
    end)
    only:row(28) -- room for the four totem rows, which sit over the other controls
    only:close()

    -- Column 3: colors and border
    local look = group(barsPage, COL[3], TOP, 202, "Colors")
    dropdown(barsPage, "Texture", look.x, look:row(DROP), TEXTURES, function() return cur().texture end,
        function(v) cur().texture = v end, texturePreview)
    -- which palette color the bar wears (the Colors page sets them), or its own
    local MODES = { health = { "health", "class", "custom" }, power = { "power", "class", "custom" },
        druidmana = { "power", "class", "custom" }, pethealth = { "health", "class", "custom" },
        tothealth = { "class", "reaction", "health", "custom" },
        enemyhealth = { "class", "reaction", "health", "custom" }, castbar = { "cast", "class", "custom" },
        targetcast = { "auto", "cast", "class", "custom" } }
    local MODE_NAMES = { health = "Health color", power = "Power color", class = "Class color",
        reaction = "Hostile / neutral / friendly", cast = "Casting / channeling", custom = "Custom",
        auto = "By kind of cast" }
    dropdown(barsPage, "Bar color", look.x, look:row(DROP), function()
        local list = {}
        for _, m in ipairs(MODES[selected] or { "class", "custom" }) do
            list[#list + 1] = { (m == "class" and (selected == "enemyhealth" or selected == "tothealth"))
                and "Class color (NPCs: hostile...)"
                or MODE_NAMES[m], m }
        end
        return list
    end, function() return cur().colorMode end, function(v) cur().colorMode = v end, textPreview)
    swatch(barsPage, "Custom color", look.x, look:row(SWATCH), function() return cur().color end, {
        get = function() return cur().colorMode end, set = function(v) cur().colorMode = v end,
        effective = function() return barColors(selFrame(), cur()) end,
    })
    swatch(barsPage, "Background color", look.x, look:row(SWATCH), function() return cur().bgColor end)
    look:close()

    local bord = group(barsPage, COL[3], look.cursor - 20, 202, "Border")
    slider(barsPage, "Thickness", bord.x, bord:row(SLIDER), 0, 10,
        function() return cur().borderSize end, function(v) cur().borderSize = v end)
    dropdown(barsPage, "Color", bord.x, bord:row(DROP), { { "Same as bar (shaded)", "bar" }, { "Custom", "custom" } },
        function() return cur().borderMode end, function(v) cur().borderMode = v end,
        textPreview)
    swatch(barsPage, "Custom border color", bord.x, bord:row(SWATCH), function() return cur().borderColor end, {
        get = function() return cur().borderMode end, set = function(v) cur().borderMode = v end,
        effective = function() return select(4, barColors(selFrame(), cur())) end,
    })
    dropdown(barsPage, "Corner radius", bord.x, bord:row(DROP), { { "None", 0 }, { "2 px", 2 }, { "4 px", 4 },
        { "8 px", 8 }, { "16 px", 16 }, { "32 px", 32 }, { "Pill (50% of height)", "pill" } },
        function() return cur().radius end, function(v) cur().radius = v end, textPreview)
    bord:close()

    -- Column 4: gradient and text
    local grad = group(barsPage, COL[4], TOP, 202, "Gradient")
    check(barsPage, "Gradient", grad.x, grad:row(ROW), function() return cur().gradient end,
        function(v) cur().gradient = v end)
    local DIRECTIONS = { { "right", "Left to right" }, { "left", "Right to left" },
        { "down", "Top to bottom" }, { "up", "Bottom to top" } }
    local dir = button(barsPage, "", 186, grad.x, grad:row(BUTTON), function()
        local i = 1
        for n, d in ipairs(DIRECTIONS) do
            if d[1] == cur().direction then i = n end
        end
        cur().direction = DIRECTIONS[i % #DIRECTIONS + 1][1]
        changed()
    end)
    local points = button(barsPage, "Gradient points...", 186, grad.x, grad:row(BUTTON), function() openStops() end)
    onRefresh(function()
        dir:SetShown(cur().gradient)
        points:SetShown(cur().gradient)
        for _, d in ipairs(DIRECTIONS) do
            if d[1] == cur().direction then dir:SetText("Direction: " .. d[2]) end
        end
    end)
    grad:close()

    local txt = group(barsPage, COL[4], grad.cursor - 20, 202, "Text")
    local textWidgets = {
        check(barsPage, "Show text", txt.x, txt:row(ROW), function() return cur().text end, function(v) cur().text = v end),
        dropdown(barsPage, "Font", txt.x, txt:row(DROP), FONTS, function() return cur().font end,
            function(v) cur().font = v end, fontPreview),
    }
    local sizeY = txt:row(SLIDER)
    textWidgets[3] = slider(barsPage, "Size", txt.x, sizeY, 6, 32, function() return cur().fontSize end,
        function(v) cur().fontSize = v end)
    textWidgets[4] = check(barsPage, "Outline", txt.x, txt:row(ROW), function() return cur().outline end,
        function(v) cur().outline = v end)
    textWidgets[5] = swatch(barsPage, "Text color", txt.x, txt:row(SWATCH), function() return cur().textColor end)
    -- health, power and enemy health: their numbers have a window of their own, sizes and colors too
    local numButton = button(barsPage, "Numbers", 186, txt.x, sizeY - 12, function() ns.toggleDialog(ns.textDialog) end)
    local noText = label(barsPage, "", "GameFontDisableSmall")
    noText:SetPoint("TOPLEFT", txt.x, txt:row(16))
    onRefresh(function()
        local many = ns.TEXT_BARS[selected] and true or false
        for i, w in ipairs(textWidgets) do w:SetShown(selected ~= "combo" and not (many and (i == 3 or i == 5))) end
        numButton:SetShown(many)
        if not (many and (section == "combat" or section == "nameplates")) then ns.textDialog:Hide() end
        noText:SetText(selected == "combo" and "Combo points show no text." or "")
    end)
    txt:close()

    -- Quest mobs page
    local qinfo = group(questPage, COL[1], TOP, 202, "Quest mobs")
    local desc = label(questPage, "Marks enemies you still need for a quest.\n\nSword: you need to kill it.\n"
        .. "Bag: it drops an item you need.\nGray: only groupmates still need it.\n\nThe icons sit in a row at "
        .. "the nameplate's top-right corner; a lone icon keeps to the row's left. Needs enemy nameplates on "
        .. "(V key).", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", qinfo.x, qinfo:row(186))
    desc:SetWidth(182)
    desc:SetJustifyH("LEFT")
    qinfo:close()

    local Q = function() return db.quest end
    local row = group(questPage, COL[1], qinfo.cursor - 20, 202, "Icon row")
    slider(questPage, "X (left / right)", row.x, row:row(SLIDER), -200, 200, function() return Q().x end,
        function(v) Q().x = v end)
    slider(questPage, "Y (down / up)", row.x, row:row(SLIDER), -200, 200, function() return Q().y end,
        function(v) Q().y = v end)
    slider(questPage, "Spacing", row.x, row:row(SLIDER), 0, 20, function() return Q().spacing end,
        function(v) Q().spacing = v end)
    row:close()

    for i, kind in ipairs({ { "kill", "Kill it (sword)" }, { "loot", "Drops a quest item (bag)" } }) do
        local function q() return db.quest[kind[1]] end
        local g = group(questPage, COL[i + 1], TOP, 202, kind[2])
        check(questPage, "Show", g.x, g:row(ROW), function() return q().show end, function(v) q().show = v end)
        dropdown(questPage, "Icon", g.x, g:row(DROP), QUEST_ICONS[kind[1]], function() return q().icon end,
            function(v) q().icon = v end, iconPreview)
        slider(questPage, "Size", g.x, g:row(SLIDER), 8, 64, function() return q().size end, function(v) q().size = v end)
        check(questPage, "Show how many are left", g.x, g:row(ROW), function() return q().count end,
            function(v) q().count = v end)
        g:close()
    end

    -- Other page, column 1: quests and merchants
    local quests = group(otherPage, COL[1], TOP, 202, "Quests")
    check(otherPage, "Auto-accept (Shift skips)", quests.x, quests:row(ROW),
        function() return db.other.autoAccept end, function(v) db.other.autoAccept = v end)
    check(otherPage, "Auto-complete (Shift skips)", quests.x, quests:row(ROW),
        function() return db.other.autoComplete end, function(v) db.other.autoComplete = v end)
    local qnote = label(otherPage, "Quests with a reward choice or a gold cost stay with you.",
        "GameFontDisableSmall")
    qnote:SetPoint("TOPLEFT", quests.x, quests:row(34))
    qnote:SetWidth(182)
    qnote:SetJustifyH("LEFT")
    quests:close()

    local merch = group(otherPage, COL[1], quests.cursor - 20, 202, "Merchants")
    check(otherPage, "Auto-sell junk (gray items)", merch.x, merch:row(ROW),
        function() return db.other.sellJunk end, function(v) db.other.sellJunk = v end)
    check(otherPage, "Auto-repair", merch.x, merch:row(ROW),
        function() return db.other.autoRepair end, function(v) db.other.autoRepair = v end)
    merch:close()


    -- Other page, column 2: Blizzard's own frames
    local blizz = group(otherPage, COL[2], TOP, 202, "Blizzard frames")
    check(otherPage, "Hide player frame", blizz.x, blizz:row(ROW),
        function() return db.regular.hidePlayerFrame end, function(v) db.regular.hidePlayerFrame = v end)
    check(otherPage, "Hide target frame", blizz.x, blizz:row(ROW),
        function() return db.regular.hideTargetFrame end, function(v) db.regular.hideTargetFrame = v end)
    check(otherPage, "Hide cast bar", blizz.x, blizz:row(ROW),
        function() return db.regular.hideBlizzCastbar end, function(v) db.regular.hideBlizzCastbar = v end)
    check(otherPage, "Hide action bar gryphons", blizz.x, blizz:row(ROW),
        function() return db.other.hideGryphons end, function(v) db.other.hideGryphons = v end)
    check(otherPage, "Bag bar only with bags", blizz.x, blizz:row(ROW),
        function() return db.other.bagsOnOpen end, function(v) db.other.bagsOnOpen = v end)
    local bagNote = label(otherPage, "The bag bar attaches to the bags. Hiding applies out of combat.",
        "GameFontDisableSmall")
    bagNote:SetPoint("TOPLEFT", blizz.x, blizz:row(34))
    bagNote:SetWidth(182)
    bagNote:SetJustifyH("LEFT")
    blizz:row(6)
    check(otherPage, "Party/raid frame hover highlight", blizz.x, blizz:row(ROW),
        function() return db.other.raidHover.show end, function(v) db.other.raidHover.show = v end)
    swatch(otherPage, "Highlight color", blizz.x, blizz:row(SWATCH), function() return db.other.raidHover.color end)
    slider(otherPage, "Highlight opacity (%)", blizz.x, blizz:row(SLIDER), 0, 100,
        function() return math.floor(db.other.raidHover.color[4] * 100 + 0.5) end,
        function(v) db.other.raidHover.color[4] = v / 100 end)
    blizz:close()

    -- Other page, column 4: what the mouse does over the bars, and the regen spinner
    local mouse = group(otherPage, COL[4], TOP, 202, "Clicking the bars")
    check(otherPage, "Left-click: target yourself", mouse.x, mouse:row(ROW),
        function() return db.regular.playerTarget end, function(v) db.regular.playerTarget = v end)
    check(otherPage, "Right-click: player menu", mouse.x, mouse:row(ROW),
        function() return db.regular.playerMenu end, function(v) db.regular.playerMenu = v end)
    check(otherPage, "Enemy health: right-click menu", mouse.x, mouse:row(ROW),
        function() return db.regular.targetMenu end, function(v) db.regular.targetMenu = v end)
    check(otherPage, "Pet: right-click menu", mouse.x, mouse:row(ROW),
        function() return db.regular.petMenu end, function(v) db.regular.petMenu = v end)
    check(otherPage, "Target of target: right-click menu", mouse.x, mouse:row(ROW),
        function() return db.regular.totMenu end, function(v) db.regular.totMenu = v end)
    check(otherPage, "Mouseover macros", mouse.x, mouse:row(ROW),
        function() return db.regular.playerMouseover end, function(v) db.regular.playerMouseover = v end)
    check(otherPage, "Highlight on mouseover", mouse.x, mouse:row(ROW),
        function() return db.regular.highlight.show end, function(v) db.regular.highlight.show = v end)
    swatch(otherPage, "Highlight color", mouse.x, mouse:row(SWATCH), function() return db.regular.highlight.color end)
    slider(otherPage, "Highlight opacity (%)", mouse.x, mouse:row(SLIDER), 0, 100,
        function() return math.floor(db.regular.highlight.color[4] * 100 + 0.5) end,
        function(v) db.regular.highlight.color[4] = v / 100 end)
    local mnote = label(otherPage, "Click and mouseover options apply out of combat and block clicks through "
        .. "the bars. The highlight doesn't.", "GameFontDisableSmall")
    mnote:SetPoint("TOPLEFT", mouse.x, mouse:row(40))
    mnote:SetWidth(182)
    mnote:SetJustifyH("LEFT")
    mouse:close()

    -- Other page, column 3: combat text and the minimap
    local cfont = group(otherPage, COL[3], TOP, 202, "Combat text font")
    dropdown(otherPage, "Damage numbers", cfont.x, cfont:row(DROP), COMBAT_FONTS,
        function() return db.other.combatFont end,
        function(v) db.other.combatFont = v; applyCombatFont() end, combatFontPreview)
    local big = otherPage:CreateFontString(nil, "OVERLAY")
    big:SetPoint("TOPLEFT", cfont.x, cfont:row(40))
    onRefresh(function()
        local pick = db.other.combatFont
        if pick == "" then pick = DEFAULT_DAMAGE_FONT end
        if not big:SetFont(pick, 30, "OUTLINE") then
            big:SetFont(DEFAULT_DAMAGE_FONT, 30, "OUTLINE")
        end
        big:SetTextColor(unpack(DAMAGE_YELLOW))
        big:SetText("123")
    end)
    local restart = label(otherPage, "Changes the scrolling text at your character right away. The "
        .. "numbers floating over enemies are drawn by the game itself, which an addon can't reach: "
        .. "for those, copy the .ttf over Fonts\\SKURRI.TTF in your WoW folder and restart.",
        "GameFontDisableSmall")
    restart:SetPoint("TOPLEFT", cfont.x, cfont:row(46))
    restart:SetWidth(182)
    restart:SetJustifyH("LEFT")
    cfont:close()

    -- Other page, column 1: show on mouseover only
    local hover = group(otherPage, COL[1], merch.cursor - 20, 202, "Show only on mouseover")
    for _, e in ipairs(HOVER_FRAMES) do
        check(otherPage, e[2], hover.x, hover:row(22),
            function() return db.other.hover[e[1]] end, function(v) db.other.hover[e[1]] = v or nil end)
    end
    local hnote = label(otherPage, "They fade in under the cursor, stay clickable and show while "
        .. "Edit Mode is open.\n\nFading one of Blizzard's own bars means touching it, and a "
        .. "touched bar can start complaining that its cooldowns cannot be drawn. If you are "
        .. "seeing that, turn the bars here off and reload.", "GameFontDisableSmall")
    hnote:SetPoint("TOPLEFT", hover.x, hover:row(74))
    hnote:SetWidth(182)
    hnote:SetJustifyH("LEFT")
    hover:close()

    local look2 = group(otherPage, COL[3], cfont.cursor - 20, 202, "Minimap look")
    local MM = function() return db.other.minimap end
    check(otherPage, "Square shape", look2.x, look2:row(ROW), function() return MM().square end,
        function(v) MM().square = v end)
    check(otherPage, "1 px border", look2.x, look2:row(ROW), function() return MM().border end,
        function(v) MM().border = v end)
    dropdown(otherPage, "Corner radius", look2.x, look2:row(DROP), { { "None (square)", 0 }, { "4 px", 4 },
        { "8 px", 8 }, { "16 px", 16 }, { "32 px", 32 }, { "Round", "round" } },
        function() return MM().radius end, function(v) MM().radius = v end, textPreview)
    check(otherPage, "Hide day/night dial", look2.x, look2:row(ROW), function() return MM().hideDayNight end,
        function(v) MM().hideDayNight = v end)
    look2:close()

    local mm = group(otherPage, COL[3], look2.cursor - 20, 202, "Minimap tray and bars")
    check(otherPage, "Tray for addon icons", mm.x, mm:row(ROW), function() return MM().tray end,
        function(v) MM().tray = v end)
    check(otherPage, "Tray holds tracking + calendar", mm.x, mm:row(ROW),
        function() return MM().trayBlizzard end, function(v) MM().trayBlizzard = v end)
    slider(otherPage, "Tray position (%)", mm.x, mm:row(SLIDER), 0, 100,
        function() return math.floor(((store.trayAngle or 180) + 180) / 3.6 + 0.5) % 101 end,
        function(v) store.trayAngle = v * 3.6 - 180; mini.trayPlace() end)
    check(otherPage, "Info bars (zone, coords, time, ping)", mm.x, mm:row(ROW),
        function() return MM().infoBar end, function(v) MM().infoBar = v end)
    slider(otherPage, "Move X (left / right)", mm.x, mm:row(SLIDER), -1000, 1000,
        function() return MM().x end, function(v) MM().x = v end)
    slider(otherPage, "Move Y (down / up)", mm.x, mm:row(SLIDER), -1000, 1000,
        function() return MM().y end, function(v) MM().y = v end)
    local mmNote = label(otherPage, "Drag the tray icon around the minimap, or use the slider; click it to open.",
        "GameFontDisableSmall")
    mmNote:SetPoint("TOPLEFT", mm.x, mm:row(34))
    mmNote:SetWidth(182)
    mmNote:SetJustifyH("LEFT")
    mm:close()

    ----------------------------------------------------------------------------------
    -- Mage page: the conjured food and water counter
    ----------------------------------------------------------------------------------
    local M = function() return db.mage end
    local mset = group(magePage, COL[1], TOP, 202, "Food and water")
    check(magePage, "Show it", mset.x, mset:row(ROW), function() return M().show end,
        function(v) M().show = v end)
    local mlk = button(magePage, "", 186, mset.x, mset:row(BUTTON), function()
        M().locked = not M().locked
        changed()
    end)
    onRefresh(function() mlk:SetText(M().locked and "Locked (click to unlock)" or "Unlocked - drag it") end)
    slider(magePage, "X (left / right)", mset.x, mset:row(SLIDER), -1200, 1200,
        function() return M().x end, function(v) M().x = v end)
    slider(magePage, "Y (down / up)", mset.x, mset:row(SLIDER), -800, 800,
        function() return M().y end, function(v) M().y = v end)
    local mNote = label(magePage, "Counts the conjured food and water in your bags and shows only "
        .. "the best rank you carry. With none of it, the icon is the rank your level conjures.",
        "GameFontDisableSmall")
    mNote:SetPoint("TOPLEFT", mset.x, mset:row(46))
    mNote:SetWidth(182)
    mNote:SetJustifyH("LEFT")
    mset:close()

    local mlook = group(magePage, COL[2], TOP, 202, "Icons")
    slider(magePage, "Icon size", mlook.x, mlook:row(SLIDER), 12, 80, function() return M().size end,
        function(v) M().size = v end)
    slider(magePage, "Gap", mlook.x, mlook:row(SLIDER), 0, 30, function() return M().gap end,
        function(v) M().gap = v end)
    dropdown(magePage, "Side by side or stacked", mlook.x, mlook:row(DROP),
        { { "Side by side", "right" }, { "Stacked", "down" } },
        function() return M().grow end, function(v) M().grow = v end, textPreview)
    dropdown(magePage, "Which comes first", mlook.x, mlook:row(DROP),
        { { "Food, then water", false }, { "Water, then food", true } },
        function() return M().waterFirst and true or false end,
        function(v) M().waterFirst = v end, textPreview)
    dropdown(magePage, "Corner radius", mlook.x, mlook:row(DROP), { { "None (square)", 0 },
        { "Slightly rounded", 12 }, { "Rounded", 25 }, { "Circle", 50 } },
        function() return ns.ICON_MASKS[M().radius] and M().radius or 0 end,
        function(v) M().radius = v end, textPreview)
    dropdown(magePage, "Count sits", mlook.x, mlook:row(DROP), { { "In the corner", "corner" },
        { "In the middle", "center" } }, function() return M().countAt end,
        function(v) M().countAt = v end, textPreview)
    check(magePage, "Show the count", mlook.x, mlook:row(ROW), function() return M().showCount end,
        function(v) M().showCount = v end)
    mlook:close()

    local mtext = group(magePage, COL[3], TOP, 202, "The count")
    dropdown(magePage, "Font", mtext.x, mtext:row(DROP), FONTS, function() return M().font end,
        function(v) M().font = v end, fontPreview)
    slider(magePage, "Font size", mtext.x, mtext:row(SLIDER), 6, 30, function() return M().fontSize end,
        function(v) M().fontSize = v end)
    check(magePage, "Outline", mtext.x, mtext:row(ROW), function() return M().outline end,
        function(v) M().outline = v end)
    swatch(magePage, "Color", mtext.x, mtext:row(SWATCH), function() return M().color end)
    swatch(magePage, "Color when low", mtext.x, mtext:row(SWATCH), function() return M().lowColor end)
    slider(magePage, "Low is under", mtext.x, mtext:row(SLIDER), 1, 40, function() return M().low end,
        function(v) M().low = v end)
    mtext:close()

    ----------------------------------------------------------------------------------
    -- Hunter page: ammunition and the pet's mood
    ----------------------------------------------------------------------------------
    local H = function() return db.hunter end
    local hset = group(hunterPage, COL[1], TOP, 202, "Ammo and pet")
    check(hunterPage, "Show it", hset.x, hset:row(ROW), function() return H().show end,
        function(v) H().show = v end)
    check(hunterPage, "Ammunition", hset.x, hset:row(ROW), function() return H().ammo end,
        function(v) H().ammo = v end)
    local petTick = check(hunterPage, "Pet happiness", hset.x, hset:row(ROW),
        function() return H().pet end, function(v) H().pet = v end)
    local petNote = label(hunterPage, "", "GameFontDisableSmall")
    petNote:SetPoint("TOPLEFT", hset.x + 24, hset:row(14))
    onRefresh(function()
        local has = GetPetHappiness ~= nil or UnitPetHappiness ~= nil or PetFrameHappiness ~= nil
        petTick:SetEnabled(has)
        petNote:SetText(has and "" or "|cffff8888no happiness in this client|r")
    end)
    local hlk = button(hunterPage, "", 186, hset.x, hset:row(BUTTON), function()
        H().locked = not H().locked
        changed()
    end)
    onRefresh(function() hlk:SetText(H().locked and "Locked (click to unlock)" or "Unlocked - drag it") end)
    slider(hunterPage, "X (left / right)", hset.x, hset:row(SLIDER), -1200, 1200,
        function() return H().x end, function(v) H().x = v end)
    slider(hunterPage, "Y (down / up)", hset.x, hset:row(SLIDER), -800, 800,
        function() return H().y end, function(v) H().y = v end)
    local hNote = label(hunterPage, "The ammo in your ammo slot, with how many you carry, and the "
        .. "face your pet is pulling -- if this client still has pet happiness at all. Hunters "
        .. "only.", "GameFontDisableSmall")
    hNote:SetPoint("TOPLEFT", hset.x, hset:row(40))
    hNote:SetWidth(182)
    hNote:SetJustifyH("LEFT")
    hset:close()

    local hlook = group(hunterPage, COL[2], TOP, 202, "Icons")
    slider(hunterPage, "Icon size", hlook.x, hlook:row(SLIDER), 12, 80, function() return H().size end,
        function(v) H().size = v end)
    slider(hunterPage, "Gap", hlook.x, hlook:row(SLIDER), 0, 30, function() return H().gap end,
        function(v) H().gap = v end)
    dropdown(hunterPage, "Corner radius", hlook.x, hlook:row(DROP), { { "None (square)", 0 },
        { "Slightly rounded", 12 }, { "Rounded", 25 }, { "Circle", 50 } },
        function() return ns.ICON_MASKS[H().radius] and H().radius or 0 end,
        function(v) H().radius = v end, textPreview)
    dropdown(hunterPage, "Side by side or stacked", hlook.x, hlook:row(DROP),
        { { "Side by side", "right" }, { "Stacked", "down" } },
        function() return H().grow end, function(v) H().grow = v end, textPreview)
    dropdown(hunterPage, "Count sits", hlook.x, hlook:row(DROP), { { "In the corner", "corner" },
        { "In the middle", "center" } }, function() return H().countAt end,
        function(v) H().countAt = v end, textPreview)
    check(hunterPage, "Show the count", hlook.x, hlook:row(ROW), function() return H().showCount end,
        function(v) H().showCount = v end)
    hlook:close()

    local htext = group(hunterPage, COL[3], TOP, 202, "The count")
    dropdown(hunterPage, "Font", htext.x, htext:row(DROP), FONTS, function() return H().font end,
        function(v) H().font = v end, fontPreview)
    slider(hunterPage, "Font size", htext.x, htext:row(SLIDER), 6, 30, function() return H().fontSize end,
        function(v) H().fontSize = v end)
    check(hunterPage, "Outline", htext.x, htext:row(ROW), function() return H().outline end,
        function(v) H().outline = v end)
    swatch(hunterPage, "Color", htext.x, htext:row(SWATCH), function() return H().color end)
    swatch(hunterPage, "Color when low", htext.x, htext:row(SWATCH), function() return H().lowColor end)
    slider(hunterPage, "Low is under", htext.x, htext:row(SLIDER), 1, 2000,
        function() return H().low end, function(v) H().low = v end)
    htext:close()

    ----------------------------------------------------------------------------------
    -- Warlock page: the soul shards in your bags
    ----------------------------------------------------------------------------------
    local W = function() return db.warlock end
    local wset = group(lockPage, COL[1], TOP, 202, "Soul shards")
    check(lockPage, "Show it", wset.x, wset:row(ROW), function() return W().show end,
        function(v) W().show = v end)
    local wlk = button(lockPage, "", 186, wset.x, wset:row(BUTTON), function()
        W().locked = not W().locked
        changed()
    end)
    onRefresh(function() wlk:SetText(W().locked and "Locked (click to unlock)" or "Unlocked - drag it") end)
    slider(lockPage, "X (left / right)", wset.x, wset:row(SLIDER), -1200, 1200,
        function() return W().x end, function(v) W().x = v end)
    slider(lockPage, "Y (down / up)", wset.x, wset:row(SLIDER), -800, 800,
        function() return W().y end, function(v) W().y = v end)
    local wNote = label(lockPage, "Counts the soul shards in your bags. Warlocks only.",
        "GameFontDisableSmall")
    wNote:SetPoint("TOPLEFT", wset.x, wset:row(30))
    wNote:SetWidth(182)
    wNote:SetJustifyH("LEFT")
    wset:close()

    local wlook = group(lockPage, COL[2], TOP, 202, "Icon")
    slider(lockPage, "Icon size", wlook.x, wlook:row(SLIDER), 12, 80, function() return W().size end,
        function(v) W().size = v end)
    dropdown(lockPage, "Corner radius", wlook.x, wlook:row(DROP), { { "None (square)", 0 },
        { "Slightly rounded", 12 }, { "Rounded", 25 }, { "Circle", 50 } },
        function() return ns.ICON_MASKS[W().radius] and W().radius or 0 end,
        function(v) W().radius = v end, textPreview)
    dropdown(lockPage, "Count sits", wlook.x, wlook:row(DROP), { { "In the corner", "corner" },
        { "In the middle", "center" } }, function() return W().countAt end,
        function(v) W().countAt = v end, textPreview)
    check(lockPage, "Show the count", wlook.x, wlook:row(ROW), function() return W().showCount end,
        function(v) W().showCount = v end)
    slider(lockPage, "Gap", wlook.x, wlook:row(SLIDER), 0, 30, function() return W().gap end,
        function(v) W().gap = v end)
    dropdown(lockPage, "Side by side or stacked", wlook.x, wlook:row(DROP),
        { { "Side by side", "right" }, { "Stacked", "down" } },
        function() return W().grow end, function(v) W().grow = v end, textPreview)
    wlook:close()

    local warm = group(lockPage, COL[4], TOP, 202, "Demon armor")
    check(lockPage, "Show it", warm.x, warm:row(ROW), function() return W().armor end,
        function(v) W().armor = v end)
    check(lockPage, "Flash when it is gone", warm.x, warm:row(ROW), function() return W().flash end,
        function(v) W().flash = v end)
    check(lockPage, "Hide it while you are armored", warm.x, warm:row(ROW),
        function() return W().armorOnlyMissing end, function(v) W().armorOnlyMissing = v end)
    slider(lockPage, "Icon size", warm.x, warm:row(SLIDER), 12, 80,
        function() return W().armorSize or W().size end, function(v) W().armorSize = v end)
    slider(lockPage, "Font size", warm.x, warm:row(SLIDER), 6, 30,
        function() return W().armorFontSize or W().fontSize end,
        function(v) W().armorFontSize = v end)
    local warmNote = label(lockPage, "The best armor you know -- Demon Armor, or Demon Skin until "
        .. "you have it, and either one counts while it is on you. Missing, the icon flashes; "
        .. "armored, it is out of the way. This works in a fight too: when the aura calls go "
        .. "quiet the icon is looked for on Blizzard's own buff bar instead.",
        "GameFontDisableSmall")
    warmNote:SetPoint("TOPLEFT", warm.x, warm:row(56))
    warmNote:SetWidth(182)
    warmNote:SetJustifyH("LEFT")
    warm:close()

    local wtext = group(lockPage, COL[3], TOP, 202, "The count")
    dropdown(lockPage, "Font", wtext.x, wtext:row(DROP), FONTS, function() return W().font end,
        function(v) W().font = v end, fontPreview)
    slider(lockPage, "Font size", wtext.x, wtext:row(SLIDER), 6, 30, function() return W().fontSize end,
        function(v) W().fontSize = v end)
    check(lockPage, "Outline", wtext.x, wtext:row(ROW), function() return W().outline end,
        function(v) W().outline = v end)
    swatch(lockPage, "Shard color", wtext.x, wtext:row(SWATCH), function() return W().color end)
    swatch(lockPage, "Shard color when low", wtext.x, wtext:row(SWATCH), function() return W().lowColor end)
    slider(lockPage, "Low is under", wtext.x, wtext:row(SLIDER), 1, 32, function() return W().low end,
        function(v) W().low = v end)
    wtext:close()

    ----------------------------------------------------------------------------------
    -- Rogue and Shaman pages: what is on each weapon. The same settings, twice over.
    ----------------------------------------------------------------------------------
    for _, w in ipairs({ { "rogue", roguePage, "poison" }, { "shaman", shamanPage, "imbue" } }) do
        local key, page, what = w[1], w[2], w[3]
        local W = function() return db[key] end
        local wg = group(page, COL[1], TOP, 202, "Weapon " .. what)
        check(page, "Show it", wg.x, wg:row(ROW), function() return W().show end,
            function(v) W().show = v end)
        check(page, "Flash a bare weapon", wg.x, wg:row(ROW), function() return W().flash end,
            function(v) W().flash = v end)
        local wgl = button(page, "", 186, wg.x, wg:row(BUTTON), function()
            W().locked = not W().locked
            changed()
        end)
        onRefresh(function()
            wgl:SetText(W().locked and "Locked (click to unlock)" or "Unlocked - drag it")
        end)
        slider(page, "X (left / right)", wg.x, wg:row(SLIDER), -1200, 1200,
            function() return W().x end, function(v) W().x = v end)
        slider(page, "Y (down / up)", wg.x, wg:row(SLIDER), -800, 800,
            function() return W().y end, function(v) W().y = v end)
        slider(page, "Warn under (minutes)", wg.x, wg:row(SLIDER), 1, 60,
            function() return W().warn end, function(v) W().warn = v end)
        local wgNote = label(page, "One icon per hand, and only when it needs you: nothing on "
            .. "that weapon, or -- out of combat, where you can do something about it -- less "
            .. "than the minutes above left, with the number on the icon.", "GameFontDisableSmall")
        wgNote:SetPoint("TOPLEFT", wg.x, wg:row(56))
        wgNote:SetWidth(182)
        wgNote:SetJustifyH("LEFT")
        wg:close()

        local wgi = group(page, COL[2], TOP, 202, "Icons")
        slider(page, "Icon size", wgi.x, wgi:row(SLIDER), 12, 80, function() return W().size end,
            function(v) W().size = v end)
        slider(page, "Gap", wgi.x, wgi:row(SLIDER), 0, 30, function() return W().gap end,
            function(v) W().gap = v end)
        dropdown(page, "Corner radius", wgi.x, wgi:row(DROP), { { "None (square)", 0 },
            { "Slightly rounded", 12 }, { "Rounded", 25 }, { "Circle", 50 } },
            function() return ns.ICON_MASKS[W().radius] and W().radius or 0 end,
            function(v) W().radius = v end, textPreview)
        dropdown(page, "Side by side or stacked", wgi.x, wgi:row(DROP),
            { { "Side by side", "right" }, { "Stacked", "down" } },
            function() return W().grow end, function(v) W().grow = v end, textPreview)
        dropdown(page, "Minutes sit", wgi.x, wgi:row(DROP), { { "In the corner", "corner" },
            { "In the middle", "center" } }, function() return W().countAt end,
            function(v) W().countAt = v end, textPreview)
        wgi:close()

        local wgt = group(page, COL[3], TOP, 202, "The minutes")
        dropdown(page, "Font", wgt.x, wgt:row(DROP), FONTS, function() return W().font end,
            function(v) W().font = v end, fontPreview)
        slider(page, "Font size", wgt.x, wgt:row(SLIDER), 6, 30, function() return W().fontSize end,
            function(v) W().fontSize = v end)
        check(page, "Outline", wgt.x, wgt:row(ROW), function() return W().outline end,
            function(v) W().outline = v end)
        swatch(page, "Color", wgt.x, wgt:row(SWATCH), function() return W().color end)
        swatch(page, "Running out", wgt.x, wgt:row(SWATCH), function() return W().warnColor end)
        wgt:close()
    end

    ----------------------------------------------------------------------------------
    -- Buffs page: the out-of-combat check of who is missing what
    ----------------------------------------------------------------------------------
    local B = function() return db.buffs end
    local bset = group(buffPage, COL[1], TOP, 202, "Buff check")
    check(buffPage, "Show it", bset.x, bset:row(ROW), function() return B().show end,
        function(v) B().show = v end)
    check(buffPage, "Only what is missing", bset.x, bset:row(ROW), function() return B().onlyMissing end,
        function(v) B().onlyMissing = v end)
    local blk = button(buffPage, "", 186, bset.x, bset:row(BUTTON), function()
        B().locked = not B().locked
        changed()
    end)
    onRefresh(function() blk:SetText(B().locked and "Locked (click to unlock)" or "Unlocked - drag it") end)
    slider(buffPage, "X (left / right)", bset.x, bset:row(SLIDER), -1200, 1200,
        function() return B().x end, function(v) B().x = v end)
    slider(buffPage, "Y (down / up)", bset.x, bset:row(SLIDER), -800, 800,
        function() return B().y end, function(v) B().y = v end)
    local bsetNote = label(buffPage, "Checks everyone in the group against the buffs somebody here "
        .. "can give, and shows who is missing one. Out of combat only: in a fight the game "
        .. "answers nothing, so any list would be a guess.", "GameFontDisableSmall")
    bsetNote:SetPoint("TOPLEFT", bset.x, bset:row(52))
    bsetNote:SetWidth(182)
    bsetNote:SetJustifyH("LEFT")
    bset:close()

    local blook = group(buffPage, COL[2], TOP, 202, "Look")
    slider(buffPage, "Icon size", blook.x, blook:row(SLIDER), 8, 40, function() return B().size end,
        function(v) B().size = v end)
    dropdown(buffPage, "Font", blook.x, blook:row(DROP), FONTS, function() return B().font end,
        function(v) B().font = v end, fontPreview)
    slider(buffPage, "Font size", blook.x, blook:row(SLIDER), 6, 24, function() return B().fontSize end,
        function(v) B().fontSize = v end)
    check(buffPage, "Outline", blook.x, blook:row(ROW), function() return B().outline end,
        function(v) B().outline = v end)
    swatch(buffPage, "Missing color", blook.x, blook:row(SWATCH), function() return B().color end)
    blook:close()

    local bwhat = group(buffPage, COL[3], TOP, 202, "What to check")
    for _, chk in ipairs(ns.BUFF_CHECKS) do
        check(buffPage, chk.label .. " (" .. chk.from:sub(1, 1) .. chk.from:sub(2):lower() .. ")",
            bwhat.x, bwhat:row(ROW), function() return not B().skip[chk.key] end,
            function(v) B().skip[chk.key] = (not v) or nil end)
    end
    check(buffPage, "Weapon (rogue, shaman)", bwhat.x, bwhat:row(ROW),
        function() return not B().skip.weapon end,
        function(v) B().skip.weapon = (not v) or nil end)
    local bwhatNote = label(buffPage, "A row shows only when somebody in the group can actually "
        .. "give that buff. A paladin keeps one blessing per person, so any one of them counts.",
        "GameFontDisableSmall")
    bwhatNote:SetPoint("TOPLEFT", bwhat.x, bwhat:row(46))
    bwhatNote:SetWidth(182)
    bwhatNote:SetJustifyH("LEFT")
    bwhat:close()

    local FS = function() return db.other.fsr end
    local spin = group(otherPage, COL[4], mouse.cursor - 20, 202, "Mana regen spinner")
    check(otherPage, "Show", spin.x, spin:row(ROW), function() return FS().show end,
        function(v) FS().show = v end)
    dropdown(otherPage, "Attach to bar", spin.x, spin:row(DROP), function()
        local list = {}
        for _, key in ipairs(db.regular.order) do list[#list + 1] = { BARS[key].label, key } end
        return list
    end, function() return FS().bar end, function(v) FS().bar = v end, textPreview)
    slider(otherPage, "Size", spin.x, spin:row(SLIDER), 8, 96, function() return FS().size end,
        function(v) FS().size = v end)
    local spinDir = button(otherPage, "", 186, spin.x, spin:row(BUTTON), function()
        FS().fill = not FS().fill
        changed()
    end)
    onRefresh(function() spinDir:SetText(FS().fill and "Ring: Fills up" or "Ring: Drains away") end)
    slider(otherPage, "X (left / right)", spin.x, spin:row(SLIDER), -200, 200,
        function() return FS().x end, function(v) FS().x = v end)
    slider(otherPage, "Y (down / up)", spin.x, spin:row(SLIDER), -200, 200,
        function() return FS().y end, function(v) FS().y = v end)
    swatch(otherPage, "Color", spin.x, spin:row(SWATCH), function() return FS().color end)
    local spinNote = label(otherPage, "Runs until Spirit regen is back: 5 s in combat, 7 s out of it. "
        .. "Mana classes only.", "GameFontDisableSmall")
    spinNote:SetPoint("TOPLEFT", spin.x, spin:row(28))
    spinNote:SetWidth(182)
    spinNote:SetJustifyH("LEFT")
    spin:close()

    -- Four columns of cards are built; the window holds two. Columns 3 and 4 move under 1 and 2:
    -- anything placed on the page itself right of column 2 shifts left and down, and whatever
    -- hangs off those moves with it.
    ----------------------------------------------------------------------------------
    -- Colors page: the palette every bar picks from
    ----------------------------------------------------------------------------------
    local P = function() return db.colors end
    local function swatches(g, list, get)
        for _, e in ipairs(list) do swatch(colorPage, e[2], g.x, g:row(SWATCH), function() return get()[e[1]] end) end
    end
    local hcard = group(colorPage, COL[1], TOP, 202, "Health and standing")
    swatch(colorPage, "Health", hcard.x, hcard:row(SWATCH), function() return P().health end)
    swatches(hcard, { { "hostile", "Hostile" }, { "neutral", "Neutral" }, { "friendly", "Friendly" } },
        function() return P().reaction end)
    hcard:close()
    local ccard = group(colorPage, COL[1], hcard.cursor - 20, 202, "Cast bars")
    swatches(ccard, { { "cast", "Casting" }, { "channel", "Channeling" }, { "harm", "Enemy: damage" },
        { "heal", "Enemy: healing" }, { "locked", "Enemy: can't be stopped" } }, function() return P().cast end)
    ccard:close()
    local bcard = group(colorPage, COL[1], ccard.cursor - 20, 202, "Borders")
    slider(colorPage, "\"Same as bar\" shade", bcard.x, bcard:row(SLIDER), -100, 100,
        function() return P().borderShade end, function(v) P().borderShade = v end)
    local bnote = label(colorPage, "How a border that follows its bar differs from it: up to 100 "
        .. "lighter (white), down to -100 darker (black), 0 the same.", "GameFontDisableSmall")
    bnote:SetPoint("TOPLEFT", bcard.x, bcard:row(44))
    bnote:SetWidth(182)
    bnote:SetJustifyH("LEFT")
    bcard:close()
    local pcard = group(colorPage, COL[2], TOP, 202, "Power")
    swatches(pcard, ns.POWER_ORDER, function() return P().power end)
    pcard:close()
    local klass = group(colorPage, COL[2], pcard.cursor - 20, 202, "Classes")
    swatches(klass, ns.CLASS_ORDER, function() return P().class end)
    klass:close()

    -- Enemy resource dialog: beside the window, for the enemy health bar picked on the bars page
    local rd = ns.ui.Window(nil, 230, 476, "Enemy resource")
    rd:SetParent(cfg)
    rd:ClearAllPoints()
    rd:SetPoint("TOPLEFT", cfg, "TOPRIGHT", 12, 0)
    rd:Hide()
    ns.resDialog = rd
    local ry = -48
    local function rrow(h) local at = ry; ry = ry - h; return at end
    check(rd, "Hide resource text", 16, rrow(ROW), function() return cur().resHideText end,
        function(v) cur().resHideText = v end)
    for _, r in ipairs({ { "resHeight", "Height", 1, 40 }, { "resWidth", "Width (% of the bar)", 10, 100 },
        { "resX", "X", -100, 100 }, { "resY", "Y (from the bottom)", -50, 50 },
        { "resBorderSize", "Border width", 0, 10 } }) do
        slider(rd, r[2], 16, rrow(SLIDER), r[3], r[4],
            function() return cur()[r[1]] or 0 end, function(v) cur()[r[1]] = v end)
    end
    dropdown(rd, "Border color", 16, rrow(DROP), { { "Same as bar (shaded)", "bar" }, { "Custom", "custom" } },
        function() return cur().resBorderMode end,
        function(v) cur().resBorderMode = v end, textPreview)
    swatch(rd, "Custom resource border", 16, rrow(SWATCH), function() return cur().resBorderColor or { 0, 0, 0, 1 } end, {
        get = function() return cur().resBorderMode end, set = function(v) cur().resBorderMode = v end,
        effective = function()
            local f = selFrame()
            return select(4, barColors(f.resFrame or f, f.resFrame and ns.resConf(cur()) or cur()))
        end,
    })
    dropdown(rd, "Border radius", 16, rrow(DROP), { { "None", 0 }, { "2 px", 2 }, { "4 px", 4 },
        { "8 px", 8 }, { "16 px", 16 }, { "Pill (50% of height)", "pill" } },
        function() return cur().resRadius end, function(v) cur().resRadius = v end, textPreview)

    -- Level and name dialog: same place, for the same bar. The font on top, then a column each.
    local td = ns.ui.Window(nil, 440, 690, "Level and name")
    td:SetParent(cfg)
    td:ClearAllPoints()
    td:SetPoint("TOPLEFT", cfg, "TOPRIGHT", 12, 0)
    td:Hide()
    ns.tagDialog = td
    ry = -48
    local fontRow = rrow(DROP)
    dropdown(td, "Font", 16, fontRow, FONTS, function() return cur().tagFont end,
        function(v) cur().tagFont = v end, fontPreview)
    slider(td, "Size", 230, fontRow, 6, 32, function() return cur().tagSize end, function(v) cur().tagSize = v end)
    check(td, "Outline", 16, rrow(ROW), function() return cur().tagOutline end, function(v) cur().tagOutline = v end)
    local tnote = label(td, "The level takes the game's color: grey gives no experience, red is far "
        .. "above you. \"+\" marks an elite.", "GameFontDisableSmall")
    tnote:SetPoint("TOPLEFT", 16, rrow(34))
    tnote:SetWidth(408)
    tnote:SetJustifyH("LEFT")
    local SIDES = { { "Left", "LEFT" }, { "Center", "CENTER" }, { "Right", "RIGHT" } }
    local RADII = { { "None", 0 }, { "2 px", 2 }, { "4 px", 4 }, { "8 px", 8 }, { "Pill (50% of height)", "pill" } }
    local top = ry
    for i, w in ipairs({ { "Level", "tag", "tagLevel" }, { "Name", "name", "tagName" } }) do
        local x, p = 16 + (i - 1) * 214, w[2]
        -- another bar picked: the dialog is hidden, its widgets read enemy health's defaults
        local B = function() return cur()[p .. "Bg"] or DEFAULTS.regular.bars.enemyhealth[p .. "Bg"] end
        ry = top
        label(td, w[1], "GameFontNormal"):SetPoint("TOPLEFT", x, rrow(22))
        check(td, "Show " .. w[1]:lower(), x, rrow(ROW), function() return cur()[w[3]] end,
            function(v) cur()[w[3]] = v end)
        if p == "name" then
            swatch(td, "Name color", x, rrow(SWATCH), function() return cur().tagNameColor or { 1, 1, 1, 1 } end)
            local D = function() return cur().drinking or DEFAULTS.regular.bars.enemyhealth.drinking end
            check(td, "\"Drinking!\" instead, flashing", x, rrow(ROW), function() return D().show end,
                function(v) D().show = v end)
            swatch(td, "Drinking color", x, rrow(SWATCH), function() return D().color end)
        end
        if p == "tag" then
            dropdown(td, "Sits", x, rrow(DROP), { { "Free, on the bar", "free" }, { "Left of the name", "left" },
                { "Right of the name", "right" }, { "Above the name", "top" }, { "Below the name", "bottom" } },
                function() return cur().tagAttach end, function(v) cur().tagAttach = v end, textPreview)
        end
        local pos = dropdown(td, "Position", x, rrow(DROP), SIDES, function() return cur()[p .. "Anchor"] end,
            function(v) cur()[p .. "Anchor"] = v end, textPreview)
        if p == "tag" then -- beside the name, the name decides where it is
            onRefresh(function() pos:SetShown(not (cur().tagName and ns.TAG_SIDES[cur().tagAttach or ""])) end)
        end
        slider(td, "X", x, rrow(SLIDER), -100, 100, function() return cur()[p .. "X"] end,
            function(v) cur()[p .. "X"] = v end)
        slider(td, "Y", x, rrow(SLIDER), -50, 50, function() return cur()[p .. "Y"] end,
            function(v) cur()[p .. "Y"] = v end)
        check(td, "Background", x, rrow(ROW), function() return B().show end, function(v) B().show = v end)
        swatch(td, w[1] .. " background", x, rrow(SWATCH), function() return B().color end)
        slider(td, "Padding", x, rrow(SLIDER), 0, 12, function() return B().pad end, function(v) B().pad = v end)
        dropdown(td, "Corner radius", x, rrow(DROP), RADII, function() return B().radius end,
            function(v) B().radius = v end, textPreview)
    end

    -- Buffs and debuffs dialog: a tab each (where it sits on the left, its size and grid on the
    -- right), the gaps they share underneath
    local ad = ns.ui.Window(nil, 440, 660, "Buffs and debuffs")
    ad:SetParent(cfg)
    ad:ClearAllPoints()
    ad:SetPoint("TOPLEFT", cfg, "TOPRIGHT", 12, 0)
    ad:Hide()
    ns.auraDialog = ad
    local SPOTS = { { "Top, left corner", "topleft" }, { "Top, right corner", "topright" },
        { "Bottom, left corner", "bottomleft" }, { "Bottom, right corner", "bottomright" },
        { "Right side, at the top", "righttop" }, { "Left side, at the top", "lefttop" } }
    local auraTab, panes = 1, {}
    for i, k in ipairs({ { "buffs", "Buffs" }, { "debuffs", "Debuffs" } }) do
        local tab = button(ad, k[2], 100, 16 + (i - 1) * 104, -44, function() auraTab = i; changed() end)
        local pane = CreateFrame("Frame", nil, ad)
        pane:SetAllPoints(ad)
        panes[i] = pane
        onRefresh(function()
            pane:SetShown(auraTab == i)
            if auraTab == i then tab:LockHighlight() else tab:UnlockHighlight() end
        end)
        -- another bar picked: the dialog is hidden, its widgets read enemy health's defaults
        local A = function() return cur()[k[1]] or DEFAULTS.regular.bars.enemyhealth[k[1]] end
        ry = -80
        check(pane, "Show " .. k[2]:lower(), 16, rrow(ROW), function() return A().show end, function(v) A().show = v end)
        label(pane, "Anchor to", "GameFontNormalSmall"):SetPoint("TOPLEFT", 16, rrow(18) - 4)
        for _, to in ipairs({ { "bar", "The bar" }, { "other", i == 1 and "The debuffs" or "The buffs" },
            { "line", "The center line" } }) do
            check(pane, to[2], 16, rrow(ROW), function() return A().anchorTo == to[1] end,
                function() A().anchorTo = to[1] end) -- a radio: ticking one is the choice
        end
        local edge = dropdown(pane, "On the line", 16, rrow(DROP), { { "Bottom edge (above it)", "bottom" },
            { "Center", "center" }, { "Top edge (below it)", "top" } }, function() return A().lineEdge end,
            function(v) A().lineEdge = v end, textPreview)
        onRefresh(function() edge:SetShown(A().anchorTo == "line") end)
        check(pane, "Hide timer text", 16, rrow(ROW), function() return A().hideTimer end,
            function(v) A().hideTimer = v end)
        dropdown(pane, "Starts at", 16, rrow(DROP), SPOTS, function() return A().spot end,
            function(v) A().spot = v end, textPreview)
        dropdown(pane, "Grows", 16, rrow(DROP), { { "Right", "right" }, { "Left", "left" }, { "Up", "up" },
            { "Down", "down" } }, function() return A().grow end, function(v) A().grow = v end, textPreview)
        -- then: which way a new row (or column) goes; auto: away from what it hangs on
        dropdown(pane, "Then (new rows / columns)", 16, rrow(DROP), function()
            local across = A().grow == "left" or A().grow == "right"
            return across and { { "Auto", "auto" }, { "Up", "up" }, { "Down", "down" } }
                or { { "Auto", "auto" }, { "Left", "left" }, { "Right", "right" } }
        end, function() return A().wrap end, function(v) A().wrap = v end, textPreview)
        dropdown(pane, "Corner radius", 16, rrow(DROP), { { "None (square)", 0 }, { "Slightly rounded", 12 },
            { "Rounded", 25 }, { "Circle", 50 } }, function() return ns.ICON_MASKS[A().radius] and A().radius or 0 end,
            function(v) A().radius = v end, textPreview)
        ry = -80
        for _, r in ipairs({ { "x", "X", -200, 200 }, { "y", "Y", -200, 200 }, { "size", "Icon size", 8, 64 },
            { "zoom", "Zoom (% cut from each side)", 0, 30 },
            { "cols", "Columns", 1, 20 }, { "rows", "Rows", 1, 10 }, { "max", "Most icons", 1, 40 } }) do
            slider(pane, r[2], 230, rrow(SLIDER), r[3], r[4], function() return A()[r[1]] end,
                function(v) A()[r[1]] = v end)
        end
    end
    local shared = ry - 10 - 74 -- the placement column is the longer one now: three radios, the line edge
    slider(ad, "Gap between icons", 16, shared, 0, 20, function() return cur().auraGap or 0 end,
        function(v) cur().auraGap = v end)
    slider(ad, "Gap between the groups", 230, shared, 0, 40, function() return cur().auraGroupGap or 0 end,
        function(v) cur().auraGroupGap = v end)
    shared = shared - SLIDER - 6
    slider(ad, "Gap from the center line", 16, shared, 0, 40, function() return cur().auraLineGap or 0 end,
        function(v) cur().auraLineGap = v end)
    local anote = label(ad, "Your health: all your buffs and debuffs. Enemy health: what Blizzard's target "
        .. "frame shows, all buffs and on an enemy your own debuffs. A group anchored to the other sits the "
        .. "group gap away from it. On the center line, a group with the other one empty sits centered.",
        "GameFontDisableSmall")
    anote:SetPoint("TOPLEFT", 16, shared - SLIDER - 4)
    anote:SetWidth(408)
    anote:SetJustifyH("LEFT")

    -- Icon dialogs: enemy health's PvP and drinking icons, your health's status and PvP icons,
    -- a column each
    local POINTS = { { "Top left", "TOPLEFT" }, { "Top", "TOP" }, { "Top right", "TOPRIGHT" }, { "Left", "LEFT" },
        { "Center", "CENTER" }, { "Right", "RIGHT" }, { "Bottom left", "BOTTOMLEFT" }, { "Bottom", "BOTTOM" },
        { "Bottom right", "BOTTOMRIGHT" } }
    for _, spec in ipairs({
        { "iconDialog", "PvP flag", "enemyhealth", { { "pvpIcon", "PvP flag" } },
            "Shows while your target is flagged: an icon in its faction's look (free-for-all has its own), or "
            .. "your own text in the name's font and size. On the name or level it sits outside, on that side." },
        { "statusDialog", "Status and PvP icons", "health", { { "statusIcon", "Status" }, { "pvpIcon", "PvP flag" } },
            "Status: the combat icon in a fight, else the Zzz (or your text) while you are resting, else nothing. "
            .. "PvP: while you are flagged." },
    }) do
        local d = ns.ui.Window(nil, #spec[4] == 1 and 230 or 440, 640, spec[2])
        d:SetParent(cfg)
        d:ClearAllPoints()
        d:SetPoint("TOPLEFT", cfg, "TOPRIGHT", 12, 0)
        d:Hide()
        ns[spec[1]] = d
        local lowest = 0
        for i, k in ipairs(spec[4]) do
            local x = 16 + (i - 1) * 214
            -- another bar picked: the dialog is hidden, its widgets read the defaults
            local I = function() return cur()[k[1]] or DEFAULTS.regular.bars[spec[3]][k[1]] end
            ry = -48
            label(d, k[2], "GameFontNormal"):SetPoint("TOPLEFT", x, rrow(22))
            check(d, "Show", x, rrow(ROW), function() return I().show end, function(v) I().show = v end)
            -- a typed-in text: kept on Enter or clicking away, Escape puts it back
            local function textBox(title, field)
                label(d, title, "GameFontNormalSmall"):SetPoint("TOPLEFT", x, rrow(16))
                local tb = ns.ui.Input(d, 178)
                tb:SetPoint("TOPLEFT", x, rrow(30))
                tb:SetMaxLetters(24)
                local function keep()
                    I()[field] = tb:GetText()
                    tb:ClearFocus()
                    changed()
                end
                tb:SetScript("OnEnterPressed", keep)
                tb:HookScript("OnEditFocusLost", keep)
                tb:SetScript("OnEscapePressed", function() tb:SetText(I()[field] or ""); tb:ClearFocus() end)
                onRefresh(function() if not tb:HasFocus() then tb:SetText(I()[field] or "") end end)
                return tb
            end
            if k[1] == "pvpIcon" then
                dropdown(d, "Icon", x, rrow(DROP), { { "Faction emblem", "faction" }, { "Faction banner", "banner" },
                    { "Crossed swords", "swords" }, { "Skull", "skull" }, { "Text", "text" } },
                    function() return I().style end, function(v) I().style = v end, textPreview)
                textBox("Text", "text") -- with the Text look: what it says, and its color
                swatch(d, spec[3] == "health" and "Your PvP text color" or "PvP text color", x, rrow(SWATCH),
                    function() return I().textColor end)
                if spec[3] == "enemyhealth" then
                    dropdown(d, "Anchor to", x, rrow(DROP), { { "The bar", "bar" }, { "The name", "name" },
                        { "The level", "level" } }, function() return I().anchorTo end,
                        function(v) I().anchorTo = v end, textPreview)
                end
            elseif k[1] == "statusIcon" then
                dropdown(d, "Combat icon", x, rrow(DROP), COMBAT_ICONS, function() return I().style end,
                    function(v) I().style = v end, function(button, item)
                        local t = button:AttachTexture()
                        t:SetSize(20, 20)
                        setCombatArt(t, item[2])
                        return beforeName(button, item, t, 20)
                    end)
                check(d, "Show while resting", x, rrow(ROW), function() return I().rested end,
                    function(v) I().rested = v end)
                dropdown(d, "Resting shows", x, rrow(DROP), { { "The Zzz icon", "icon" }, { "Text", "text" } },
                    function() return I().restStyle end, function(v) I().restStyle = v end, textPreview)
                textBox("Resting text", "restText")
                swatch(d, "Resting text color", x, rrow(SWATCH), function() return I().restColor end)
                check(d, "Letters fade in and out in turn", x, rrow(ROW), function() return I().restWave end,
                    function(v) I().restWave = v end)
            end
            dropdown(d, "Point", x, rrow(DROP), POINTS, function() return I().point end,
                function(v) I().point = v end, textPreview)
            slider(d, "X", x, rrow(SLIDER), -200, 200, function() return I().x end, function(v) I().x = v end)
            slider(d, "Y", x, rrow(SLIDER), -100, 100, function() return I().y end, function(v) I().y = v end)
            slider(d, "Size", x, rrow(SLIDER), 8, 64, function() return I().size end, function(v) I().size = v end)
            lowest = math.min(lowest, ry)
        end
        local note = label(d, spec[5], "GameFontDisableSmall")
        note:SetPoint("TOPLEFT", 16, lowest - 4)
        note:SetWidth(408)
        note:SetJustifyH("LEFT")
    end

    -- Numbers dialog: percent, current and current / max for the bar picked, a row each
    local nd = ns.ui.Window(nil, 440, 520, "Numbers")
    nd:SetParent(cfg)
    nd:ClearAllPoints()
    nd:SetPoint("TOPLEFT", cfg, "TOPRIGHT", 12, 0)
    nd:Hide()
    ns.textDialog = nd
    local NSIDES = { { "Left", "LEFT" }, { "Center", "CENTER" }, { "Right", "RIGHT" } }
    ry = -48
    for _, k in ipairs({ { "percent", "Percent" }, { "current", "Current" }, { "currentmax", "Current / max" } }) do
        -- another bar picked: the dialog is hidden, its widgets read health's defaults
        local T = function() return (cur().texts or DEFAULTS.regular.bars.health.texts)[k[1]] end
        local top = ry
        label(nd, k[2], "GameFontNormal"):SetPoint("TOPLEFT", 16, top)
        check(nd, "Show", 16, top - 22, function() return T().show end, function(v) T().show = v end)
        dropdown(nd, "Position", 16, top - 46, NSIDES, function() return T().anchor end,
            function(v) T().anchor = v end, textPreview)
        slider(nd, "Size", 16, top - 96, 6, 32, function() return T().size end, function(v) T().size = v end)
        slider(nd, "X", 230, top - 22, -200, 200, function() return T().x end, function(v) T().x = v end)
        slider(nd, "Y", 230, top - 68, -50, 50, function() return T().y end, function(v) T().y = v end)
        swatch(nd, k[2] .. " color", 230, top - 118, function() return T().color end)
        ry = top - 152
    end
    local nnote = label(nd, "Font and outline are the bar's, on its Text card. \"Show text\" there turns "
        .. "all three off at once.", "GameFontDisableSmall")
    nnote:SetPoint("TOPLEFT", 16, ry)
    nnote:SetWidth(408)
    nnote:SetJustifyH("LEFT")

    for _, page in pairs(ns.pages) do ns.foldColumns(page, COL, TOP) end
    ns.configHeight = math.max(-(ns.sidebarBottom or 0) + 24, 640)
    cfg:SetHeight(math.min(ns.configHeight, math.floor(UIParent:GetHeight()) - 40))
end

function ns.ToggleConfig()
    if not db then return end
    if not cfg then
        buildConfig() -- a frame is on screen the moment it is made, so there is nothing to flip
        cfg:Show()
    else
        cfg:SetShown(not cfg:IsShown())
    end
    ns.cfg = cfg
    if cfg:IsShown() then changed() end
end
-- /bs: the options window, opened on Bar Stack; closes it if that is already what is on screen
function ns.ShowBarStack()
    if cfg and cfg:IsShown() and section == "barstack" then cfg:Hide() return end
    section, mode = "barstack", "regular"
    if cfg and cfg:IsShown() then changed() else ns.ToggleConfig() end
end
WolfpackAddon_Toggle = ns.ToggleConfig -- addon compartment (retail only, Forever has none)

SLASH_WOLFPACKADDON1 = "/wolfpack"
SLASH_WOLFPACKADDON2 = "/wp"
SLASH_WOLFPACKADDON3 = "/cpd" -- the old name still works
-- Watches, from login, whether anything still says "that was a critical hit". The combat log
-- is gone here and registering it is itself blocked, so only ordinary events are tried:
-- UNIT_COMBAT, which vanilla used for exactly this, and the scrolling combat text feed.
-- /cpd crit says what has arrived.
ns.critSeen = { counts = {}, samples = {} }
ns.critEv = CreateFrame("Frame")
ns.critEv:SetScript("OnEvent", function(_, event, ...)
    local seen = ns.critSeen
    seen.counts[event] = (seen.counts[event] or 0) + 1
    local bits = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        bits[#bits + 1] = readable(v) and tostring(v):sub(1, 20) or "<secret>"
    end
    local line = table.concat(bits, " ")
    if line:find("CRIT") then
        seen.samples[event .. " CRIT"] = line
    elseif not seen.samples[event] then
        seen.samples[event] = line
    end
end)
pcall(ns.critEv.RegisterUnitEvent, ns.critEv, "UNIT_COMBAT", "player", "target")
pcall(ns.critEv.RegisterEvent, ns.critEv, "COMBAT_TEXT_UPDATE")

function ns.CritReport()
    local function say(t) print("|cff88ccffWolfpack:|r " .. t) end
    say("what has arrived since login (hit something a few times first):")
    local any = false
    for event, n in pairs(ns.critSeen.counts) do
        any = true
        say(("  %s: %d  %s"):format(event, n, ns.critSeen.samples[event] or ""))
    end
    for key, sample in pairs(ns.critSeen.samples) do
        if key:find("CRIT") then say("  |cff55ff55" .. key .. ":|r " .. sample) end
    end
    if not any then say("  nothing at all: no crit is visible to an addon here") end
end

-- /cpd auras: says which aura calls this client has and whether they answer right now, which
-- is the only way to tell from inside the game why a buff icon is missing. Run it twice: once
-- out of combat and once in combat, with the buff actually on you.
function ns.AuraReport(spellName)
    local function say(t) print("|cff88ccffWolfpack:|r " .. t) end
    local sp = { name = (spellName ~= "" and spellName) or "Renew", id = 0 }
    say(("combat %s, issecretvalue %s, looking for %s -- have it on you when you run this")
        :format(tostring(InCombatLockdown()), tostring(issecretvalue ~= nil), sp.name))

    local function report(label, fn, ...)
        local args = { ... }
        local ok, res = pcall(function() return fn(unpack(args)) end)
        if not ok then
            say(label .. ": refused (" .. tostring(res):match("[^\n]*"):sub(1, 60) .. ")")
        elseif res == nil then
            say(label .. ": answered, nothing")
        else
            local n = 0
            pcall(function() for _ in ipairs(res) do n = n + 1 end end)
            local extra = ""
            pcall(function()
                extra = ", instance " .. (readable(res.auraInstanceID) and "readable" or "secret")
                    .. ", name " .. (readable(res.name) and "readable" or "secret")
            end)
            say(label .. ": ANSWERED" .. (n > 0 and (", " .. n .. " entries") or extra))
        end
    end

    local A = C_UnitAuras
    if A.GetAuraDataBySpellName then
        report("byName(no filter)", A.GetAuraDataBySpellName, "player", sp.name)
        report("byName(HELPFUL)", A.GetAuraDataBySpellName, "player", sp.name, "HELPFUL")
        report("byName(HELPFUL|PLAYER)", A.GetAuraDataBySpellName, "player", sp.name, "HELPFUL|PLAYER")
    else
        say("byName: not on this client")
    end
    if A.GetPlayerAuraBySpellID then
        report("playerAuraBySpellID", A.GetPlayerAuraBySpellID, sp.id or 0)
    else
        say("playerAuraBySpellID: not on this client")
    end
    if AuraUtil and AuraUtil.FindAuraByName then
        report("AuraUtil.FindAuraByName", AuraUtil.FindAuraByName, sp.name, "player", "HELPFUL")
    end
    if UnitBuff then report("UnitBuff(1)", UnitBuff, "player", 1) end
    report("GetUnitAuras HELPFUL", function() return A.GetUnitAuras("player", "HELPFUL|PLAYER", 40) end)
    report("GetUnitAuras HARMFUL|RAID", function() return A.GetUnitAuras("player", "HARMFUL|RAID", 8) end)
    report("GetAuraDataByIndex(1)", A.GetAuraDataByIndex, "player", 1, "HELPFUL|PLAYER")
end

-- /wp armor -- what the warlock icon thinks it sees, for when it shows up at the wrong time.
function ns.ArmorReport()
    local function say(t) print("|cff88ccffWolfpack:|r " .. t) end
    say(InCombatLockdown() and "in combat -- only the buff bar can answer" or "out of combat")
    for _, sp in ipairs(wl.armors) do
        local want = wl.icons(sp[2])
        local ok, data = pcall(function()
            return C_UnitAuras.GetAuraDataBySpellName("player", sp[1], "HELPFUL")
        end)
        local bar = wl.iconOnBuffBar(want)
        say(("%s: icon %s | aura %s | buff bar %s"):format(sp[1], tostring(want),
            ok and (data and "found" or "not on you") or "call refused",
            bar == nil and "no answer" or tostring(bar)))
    end
    say(("remembered: %s%s"):format(tostring(wl.memoUp),
        wl.memoSp and (" (" .. wl.memoSp[1] .. ")") or ""))
    local sp, up = wl.armor()
    say(("level %s -- verdict: %s, buffed = %s"):format(tostring(UnitLevel("player")),
        sp and sp[1] or "none", tostring(up)))
end

-- /wp pet -- which of the happiness routes, if any, this build still answers on.
function ns.PetReport()
    local function say(t) print("|cff88ccffWolfpack:|r " .. t) end
    local function shot(what, fn)
        local ok, v = pcall(fn)
        say(("%s: %s %s"):format(what, ok and type(v) or "error", tostring(v)))
    end
    say(("pet exists = %s, name = %s"):format(tostring(UnitExists("pet")),
        tostring(UnitName("pet"))))
    shot("GetPetHappiness", function() return GetPetHappiness() end)
    shot("UnitPetHappiness", function() return UnitPetHappiness("pet") end)
    shot("PetFrameHappiness", function()
        return PetFrameHappiness and select(2, PetFrameHappiness:GetTexCoord())
    end)
    shot("hn.happiness", hn.happiness)
    local function keys(t, want)
        local out = {}
        if type(t) == "table" then
            for k, v in pairs(t) do
                if type(k) == "string" and (not want or k:lower():find(want)) then
                    out[#out + 1] = k .. (type(v) == "number" and ("=" .. v) or "")
                end
            end
        end
        table.sort(out)
        return #out > 0 and table.concat(out, ", ") or "nothing"
    end
    local f = PetFrameHappiness
    say(("PetFrameHappiness: %s %s"):format(type(f),
        type(f) == "table" and f.GetObjectType and f:GetObjectType() or ""))
    if type(f) == "table" then
        say("  its own keys: " .. keys(f))
        if f.GetRegions then
            for i, r in ipairs({ f:GetRegions() }) do
                local ok, tex = pcall(function() return r.GetTexture and r:GetTexture() end)
                local ok2, a = pcall(function() return r.GetAtlas and r:GetAtlas() end)
                local ok3, c = pcall(function()
                    return r.GetTexCoord and table.concat({ r:GetTexCoord() }, " ")
                end)
                say(("  region %d: %s tex=%s atlas=%s coords=%s"):format(i,
                    r.GetObjectType and r:GetObjectType() or "?", ok and tostring(tex) or "-",
                    ok2 and tostring(a) or "-", ok3 and tostring(c) or "-"))
            end
        end
    end
    say("PetHappinessIndicatorMixin: " .. keys(PetHappinessIndicatorMixin))
    say("PetPaperDollPetHappinessInfo: " .. keys(PetPaperDollPetHappinessInfo))
    local api = {}
    for name, t in pairs(_G) do
        if type(name) == "string" and name:find("^C_") and type(t) == "table" then
            for k in pairs(t) do
                if type(k) == "string" and k:lower():find("happ") then
                    api[#api + 1] = name .. "." .. k
                end
            end
        end
    end
    table.sort(api)
    say("namespaced calls: " .. (#api > 0 and table.concat(api, ", ") or "nothing"))
    local names = { "UI-PetHappiness" }
    for i = 1, 3 do
        names[#names + 1] = "UI-PetHappiness" .. i
        names[#names + 1] = "PetHappiness" .. i
        names[#names + 1] = "UI-HUD-UnitFrame-Player-PetFrame-Happiness" .. i
    end
    local atlases = {}
    for _, n in ipairs(names) do
        local ok, info = pcall(function() return C_Texture.GetAtlasInfo(n) end)
        if ok and type(info) == "table" then
            atlases[#atlases + 1] = ("%s (%sx%s)"):format(n, tostring(info.width),
                tostring(info.height))
        end
    end
    say("atlases that exist: " .. (#atlases > 0 and table.concat(atlases, ", ") or "none"))
    local look = hn.happyLook()
    say("what we would draw: " .. (look and (look.atlas or tostring(look.tex)) or "the old file"))
end

-- /wp flight -- whether the route is being caught, and what is remembered.
function ns.FlightReport()
    local function say(t) print("|cff88ccffWolfpack:|r " .. t) end
    say("on a taxi: " .. tostring(ft.flying()) .. ", timing since: " .. tostring(ft.startedAt))
    say("hooked: " .. (ft.hooked and #ft.hooked > 0 and table.concat(ft.hooked, ", ") or "nothing"))
    say("TakeTaxiNode is a " .. type(TakeTaxiNode) .. ", TaxiNodeName a " .. type(TaxiNodeName)
        .. ", C_TaxiMap a " .. type(C_TaxiMap))
    say("standing at: " .. tostring(ft.here()))
    local nodes = {}
    pcall(function()
        for _, n in ipairs(C_TaxiMap.GetAllTaxiNodes(C_Map.GetBestMapForUnit("player")) or {}) do
            nodes[#nodes + 1] = ("%s[%s/%s]"):format(n.name or "?", tostring(n.slotIndex),
                tostring(n.state))
        end
    end)
    say("flight map: " .. (#nodes > 0 and table.concat(nodes, ", "):sub(1, 260) or "nothing open"))
    say("last route caught: " .. (ft.key() or "none") .. ", known: " .. tostring(ft.known()))
    local n = 0
    for _ in pairs((store and store.flights) or {}) do n = n + 1 end
    say(n .. " routes remembered")
end

-- /wp heal -- which of the incoming-heal calls this build has, and what they say right now.
function ns.HealReport()
    local function say(t) print("|cff88ccffWolfpack:|r " .. t) end
    say("CreateUnitHealPredictionCalculator: " .. type(CreateUnitHealPredictionCalculator)
        .. ", the calculator itself: " .. type(healCalc))
    say("UnitGetDetailedHealPrediction: " .. type(UnitGetDetailedHealPrediction)
        .. ", UnitGetIncomingHeals: " .. type(UnitGetIncomingHeals))
    local ok, heals = pcall(function() return UnitGetIncomingHeals("player") end)
    say(("UnitGetIncomingHeals(player): %s %s"):format(tostring(ok),
        readable(heals) and tostring(heals) or "<secret>"))
    if healCalc and UnitGetDetailedHealPrediction then
        local ok2, got = pcall(function()
            UnitGetDetailedHealPrediction("player", "player", healCalc)
            return healCalc:GetIncomingHeals()
        end)
        say(("the calculator says: %s %s"):format(tostring(ok2),
            readable(got) and tostring(got) or "<secret>"))
    end
    say("the bar is switched on: " .. tostring(db and db.regular.bars.health.heal))
end

function ns.CastReport()
    local function say(t) print("|cff88ccffWolfpack:|r " .. t) end
    local c = db and db.regular.bars.targetcast
    say("the bar is on: " .. tostring(c and c.show) .. ", in the list at: "
        .. tostring((function()
            for i, k in ipairs(db and db.regular.order or {}) do
                if k == "targetcast" then return i end
            end
        end)()))
    say("frame exists: " .. tostring(ns.frames.targetcast ~= nil) .. ", shown: "
        .. tostring(ns.frames.targetcast and ns.frames.targetcast:IsShown()))
    local got = { pcall(UnitCastingInfo, "target") }
    say(("UnitCastingInfo(target): %s %s icon %s cannot-stop %s"):format(tostring(got[1]),
        tostring(got[2]), tostring(got[4]), tostring(got[9])))
    local chan = { pcall(UnitChannelInfo, "target") }
    say(("UnitChannelInfo(target): %s %s"):format(tostring(chan[1]), tostring(chan[2])))
    say("UnitCastingDuration: " .. type(UnitCastingDuration) .. ", for the target: "
        .. tostring(({ pcall(UnitCastingDuration, "target") })[2]))
    say("your own cast right now: " .. tostring(({ pcall(UnitCastingInfo, "player") })[2]))
end

SlashCmdList.WOLFPACKADDON = function(msg)
    msg = (msg or ""):lower()
    if msg:find("aura") then return safe(ns.AuraReport, (msg:gsub("^%s*auras?%s*", ""))) end
    if msg:find("crit") then return safe(ns.CritReport) end
    if msg:find("armor") then return safe(ns.ArmorReport) end
    if msg:find("pet") then return safe(ns.PetReport) end
    if msg:find("flight") then return safe(ns.FlightReport) end
    if msg:find("heal") then return safe(ns.HealReport) end
    if msg:find("cast") then return safe(ns.CastReport) end
    safe(ns.ToggleConfig)
end

-- Minimap icon: left-click options, right-click lock/unlock, drag to move around the minimap.
-- ponytail: assumes a round minimap; square minimap addons would need corner math.
local miniBtn = ignoreLayout(CreateFrame("Button", "WolfpackAddonMinimapButton", Minimap))
miniBtn:SetSize(31, 31)
miniBtn:SetFrameStrata("MEDIUM")
miniBtn:SetFrameLevel(8)
miniBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local miniIcon = miniBtn:CreateTexture(nil, "BACKGROUND")
miniIcon:SetSize(20, 20)
miniIcon:SetPoint("TOPLEFT", 7, -5)
miniIcon:SetTexture("Interface\\Icons\\Ability_Rogue_Eviscerate")
local miniBorder = miniBtn:CreateTexture(nil, "OVERLAY")
miniBorder:SetSize(53, 53)
miniBorder:SetPoint("TOPLEFT")
miniBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

placeMini = function()
    local a, r = math.rad(store.minimapAngle), Minimap:GetWidth() / 2 + 10
    miniBtn:ClearAllPoints()
    miniBtn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

miniBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
miniBtn:RegisterForDrag("LeftButton")
miniBtn:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then
        db.locked = not db.locked
        changed()
    else
        safe(ns.ToggleConfig)
    end
end)
miniBtn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local s = Minimap:GetEffectiveScale()
        store.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
        placeMini()
    end)
end)
miniBtn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
miniBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Wolfpack Addon")
    GameTooltip:AddLine("Left-click: options", 1, 1, 1)
    GameTooltip:AddLine("Right-click: lock / unlock bars", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this icon", 1, 1, 1)
    GameTooltip:Show()
end)
miniBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

------------------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------------------
local ev = CreateFrame("Frame")

-- Registering an event this client lacks throws, so each one is guarded.
local function listen(event, ...)
    if ... then pcall(ev.RegisterUnitEvent, ev, event, ...) else pcall(ev.RegisterEvent, ev, event) end
end

-- Auto-accept: quest windows and party members' escort quests. Quests started from items or
-- area triggers are left to Blizzard, which already turns those into popups.
local function autoAccept(event, startItem)
    if not db.other.autoAccept or IsShiftKeyDown() then return end
    if event == "QUEST_ACCEPT_CONFIRM" then
        ConfirmAcceptQuest()
        StaticPopup_Hide("QUEST_ACCEPT")
    elseif (startItem or 0) == 0 and not (QuestIsFromAreaTrigger and QuestIsFromAreaTrigger()) then
        -- neither call is on Anniversary or Classic Era, which have no such quests anyway
        if QuestGetAutoAccept and QuestGetAutoAccept() then AcknowledgeAutoAcceptQuest() else AcceptQuest() end
    end
end

-- Auto-complete: hand in the items and take the reward. Several rewards to choose from, or a
-- gold cost, stay with you.
local function autoComplete(event)
    if not db.other.autoComplete or IsShiftKeyDown() then return end
    if event == "QUEST_PROGRESS" then
        if IsQuestCompletable() then CompleteQuest() end
    elseif event == "QUEST_COMPLETE" then
        local choices = GetNumQuestChoices()
        if choices <= 1 and (GetQuestMoneyToGet() or 0) == 0 then GetQuestReward(choices) end
    end
end

-- An NPC's quest list (gossip window, or the old multi-quest greeting): turn in what's finished,
-- then take the next quest, one per opening. Trainer, vendor and other gossip options are never
-- touched. `picked` stops a window that reopens from looping on the same quest; it is dropped
-- when another NPC is used, or once the quest windows have been closed for a moment.
local picked, pickedFrom = {}, nil

local function npcQuests()
    if IsShiftKeyDown() then return end
    local guid = UnitGUID("npc")
    if guid ~= pickedFrom then
        wipe(picked)
        pickedFrom = guid
    end
    local function take(key, fn, ...)
        if picked[key] then return false end
        picked[key] = true
        fn(...)
        return true
    end
    -- Newer clients list gossip quests in C_GossipInfo, by quest ID. Anniversary and Classic Era
    -- have the old flat lists instead (6 values per active quest, 7 per available one), picked
    -- by position.
    local G = C_GossipInfo
    if db.other.autoComplete then
        if G and G.GetActiveQuests then
            for _, q in ipairs(G.GetActiveQuests() or {}) do
                if q.isComplete and take("done" .. q.questID, G.SelectActiveQuest, q.questID) then return end
            end
        elseif GetGossipActiveQuests then
            local info = { GetGossipActiveQuests() }
            for i = 1, #info / 6 do
                if info[(i - 1) * 6 + 4] and take("oldDone" .. i, SelectGossipActiveQuest, i) then return end
            end
        end
        for i = 1, GetNumActiveQuests() do
            if select(2, GetActiveTitle(i)) and take("greetDone" .. i, SelectActiveQuest, i) then return end
        end
    end
    if db.other.autoAccept then
        if G and G.GetAvailableQuests then
            for _, q in ipairs(G.GetAvailableQuests() or {}) do
                if take("new" .. q.questID, G.SelectAvailableQuest, q.questID) then return end
            end
        elseif GetGossipAvailableQuests then
            for i = 1, select("#", GetGossipAvailableQuests()) / 7 do
                if take("oldNew" .. i, SelectGossipAvailableQuest, i) then return end
            end
        end
        for i = 1, GetNumAvailableQuests() do
            if take("greetNew" .. i, SelectAvailableQuest, i) then return end
        end
    end
end

local swingTicker = CreateFrame("Frame")
ns.swingTicker = swingTicker
local swingShown = 0 -- which rows were up last tick; a change means the stack must re-flow
local function swingTick()
    local mask = 0
    for i, kind in ipairs(SWING_TYPES) do
        if swingActive(kind[3]) then mask = mask + 2 ^ (i - 1) end
    end
    if mask ~= swingShown then
        swingShown = mask
        safe(Refresh)
    else
        for _, set in pairs(swingFrames) do
            for _, f in ipairs(set) do
                if f:IsShown() then safe(ns.fill, f) end
            end
        end
    end
    if not swingActive() then swingTicker:SetScript("OnUpdate", nil) end
end

-- A swing starts: duration in seconds, swing type 0 main hand, 1 off hand, 2 ranged.
-- Either may arrive secret, and the timer does math on both every frame: a secret one would
-- throw there, over and over, and stop the whole stack from laying out. Such a swing is left
-- untimed instead.
function ns.startSwing(duration, kind)
    if not (readable(duration) and readable(kind) and type(duration) == "number" and duration > 0
        and type(kind) == "number") then return end
    swingState[kind] = { start = GetTime(), duration = duration }
    swingTicker:SetScript("OnUpdate", swingTick)
    swingTick()
end

-- Anniversary and Classic Era have no PLAYER_SWING (Forever does), but their combat log still
-- tells addons when you swing: a hit or a miss starts the next one, as long as your weapon's
-- current speed. Dodges and parries count too; they are swings all the same.
-- Midnight (12.x) keeps the combat log from addons, so only the classic clients read it.
ns.swingLog = not C_SwingTimer and CombatLogGetCurrentEventInfo ~= nil and select(4, GetBuildInfo()) < 100000
function ns.swingFromLog()
    local _, sub, _, source, _, _, _, _, _, _, _, a12, a13, _, _, _, _, _, _, _, a21 = CombatLogGetCurrentEventInfo()
    if source ~= UnitGUID("player") then return end
    local off
    if sub == "SWING_DAMAGE" then off = a21     -- isOffHand, after the damage fields
    elseif sub == "SWING_MISSED" then off = a13 -- missType, isOffHand
    else return end
    local main, offSpeed = UnitAttackSpeed("player")
    if off then ns.startSwing(offSpeed, 1) else ns.startSwing(main, 0) end
end

local petEv = CreateFrame("Frame") -- same handler as ev, for pet unit events

-- Auto-sell junk: gray items that have a sell price, one every 0.2 s while the merchant window
-- is open. Nothing else is ever sold, and closing the window stops it.
local sellTicker
-- Repairs everything at a merchant that can, out of your own money, and says what it cost.
local function autoRepair()
    if not db.other.autoRepair then return end
    if not (CanMerchantRepair and CanMerchantRepair()) then return end
    local ok, cost, canRepair = pcall(GetRepairAllCost)
    if not ok or not canRepair or (cost or 0) <= 0 then return end
    if GetMoney() < cost then
        print("|cffff5555Wolfpack Addon:|r not enough money to repair (" .. ns.money(cost) .. ")")
        return
    end
    RepairAllItems()
    print("|cff33ff99Wolfpack Addon|r repaired for " .. ns.money(cost))
end

local function sellJunk()
    if sellTicker or not db.other.sellJunk then return end
    local poor = (Enum.ItemQuality and Enum.ItemQuality.Poor) or 0
    local queue, before = {}, GetMoney()
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == poor and not info.hasNoValue and not info.isLocked then
                queue[#queue + 1] = { bag, slot }
            end
        end
    end
    if #queue == 0 then return end
    local i = 0
    sellTicker = C_Timer.NewTicker(0.2, function(ticker)
        i = i + 1
        local item = queue[i]
        if item and MerchantFrame and MerchantFrame:IsShown() then
            C_Container.UseContainerItem(item[1], item[2])
            return
        end
        ticker:Cancel()
        sellTicker = nil
        C_Timer.After(0.5, function() -- the money arrives a moment after the last sale
            local earned = GetMoney() - before
            if earned > 0 then print("|cff33ff99Wolfpack Addon|r sold junk for " .. ns.money(earned)) end
        end)
    end, #queue + 1)
end

local function stopSelling()
    if sellTicker then
        sellTicker:Cancel()
        sellTicker = nil
    end
end

-- The flight bar is the one bar the game will not animate for us -- there is no duration object
-- for a taxi ride -- so it is redrawn on a ticker, and only while the griffin has you.
ft.ticker = CreateFrame("Frame")
ft.ticker.since = 0
ft.ticker:SetScript("OnUpdate", function(self, elapsed)
    if not db then return end
    self.since = self.since + elapsed
    if self.since < 0.2 then return end
    self.since = 0
    safe(ft.tick)
    if ft.moved then -- takeoff or landing: the bar joins or leaves the stack
        ft.moved = nil
        changed()
    end
    if not (ft.startedAt or ns.previewing()) then return end
    for _, set in ipairs({ frames, plateFrames }) do
        local f = set.flight
        if f and f:IsShown() then safe(ns.fill, f) end
    end
end)

local function fillShown(...)
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if frames[key]:IsShown() then safe(ns.fill, frames[key]) end
        if plateFrames[key]:IsShown() then safe(ns.fill, plateFrames[key]) end
    end
end

-- Nothing says when your target's target loses health, so its bar asks five times a second.
ns.totPoll = CreateFrame("Frame")
ns.totPoll.wait = 0
ns.totPoll:SetScript("OnUpdate", function(self, elapsed)
    self.wait = self.wait - (elapsed or 0)
    if self.wait > 0 then return end
    self.wait = 0.2
    for _, set in ipairs({ frames, plateFrames }) do
        if set.tothealth:IsShown() then safe(ns.fill, set.tothealth) end
    end
end)

ev:SetScript("OnEvent", function(_, event, unit, arg2, arg3)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then -- by far the busiest, so asked first
        safe(ns.swingFromLog)
    elseif event == "ADDON_LOADED" then
        if unit == ADDON then applyCombatFont() end
    elseif event == "PLAYER_LOGIN" then
        -- ponytail: settings saved before profiles existed are dropped (the beta never loaded them anyway)
        store = type(WolfpackAddonDB) == "table" and WolfpackAddonDB.profiles and WolfpackAddonDB
            or { profiles = {}, chars = {} }
        WolfpackAddonDB = store
        store.minimapAngle = store.minimapAngle or 220
        store.classProfiles = store.classProfiles or {} -- [class token] = profile name
        -- every profile, not just the one in use: a bar added since it was saved belongs on all
        -- of them, and switching to one later should not be the first time it appears
        for _, prof in pairs(store.profiles) do
            for _, which in ipairs({ "regular", "nameplate" }) do
                ns.repairOrder(prof[which], DEFAULTS[which].order)
            end
        end
        store.flights = store.flights or {} -- ["Ironforge > Menethil Harbor"] = seconds
        safe(ft.hook)
        seedFromBaked()
        classProfile, class = UnitClass("player")
        playerName = UnitName("player")
        charKey = playerName .. " - " .. GetRealmName()
        for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
            "UNIT_SPELLCAST_SUCCEEDED",
            "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
            "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE" }) do
            listen(e, "player", "target")
        end
        listen("UNIT_HEALTH", "player", "target")
        listen("UNIT_MAXHEALTH", "player", "target")
        listen("UNIT_ABSORB_AMOUNT_CHANGED", "player")
        for _, e in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_LEVEL_UP" }) do
            listen(e)
        end
        listen("UNIT_HEAL_PREDICTION", "player", "target")
        listen("UNIT_PET", "player") -- pet summoned, dismissed or swapped
        pcall(petEv.RegisterUnitEvent, petEv, "UNIT_HEALTH", "pet")
        pcall(petEv.RegisterUnitEvent, petEv, "UNIT_MAXHEALTH", "pet")
        for _, e in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
            listen(e, "player", "target") -- target: the enemy resource bar
        end
        listen("UNIT_QUEST_LOG_CHANGED", "player")
        listen("UNIT_AURA", "target", "player") -- buffs and debuffs on both health bars; drinking
        listen("UNIT_FACTION", "target", "player") -- PvP flags
        listen("UNIT_TARGET", "target") -- your target's target changed: target of target
        for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM", "PLAYER_TARGET_CHANGED",
            "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE", "PLAYER_REGEN_ENABLED",
            "QUEST_DETAIL", "QUEST_ACCEPT_CONFIRM", "QUEST_PROGRESS", "QUEST_COMPLETE", "GOSSIP_SHOW", "QUEST_GREETING",
            "PLAYER_REGEN_DISABLED", "PLAYER_UPDATE_RESTING", "PLAYER_SWING", "PLAYER_TOTEM_UPDATE", "MERCHANT_SHOW", "MERCHANT_CLOSED",
            "GOSSIP_CLOSED" }) do
            listen(e)
        end
        if ns.swingLog then listen("COMBAT_LOG_EVENT_UNFILTERED") end -- swings, where no PLAYER_SWING
        inCombat = InCombatLockdown() -- a /reload mid-fight
        ns.inCombat = inCombat
        local mine = store.chars[charKey]
        if not (mine and store.profiles[mine]) then
            mine = store.classProfiles and store.classProfiles[class or ""]
        end
        useProfile(store.profiles[mine or ""] and mine or classProfile)
        placeMini()
    elseif event == "UNIT_AURA" or event == "UNIT_FACTION" or event == "PLAYER_UPDATE_RESTING" then
        for _, set in ipairs({ frames, plateFrames }) do
            if set.enemyhealth:IsShown() and unit == "target" then
                if event == "UNIT_AURA" then
                    safe(ns.layoutAuras, set.enemyhealth)
                    safe(ns.layoutTag, set.enemyhealth) -- drinking
                end
                safe(ns.layoutBadges, set.enemyhealth)
            end
            if set.health:IsShown() and unit ~= "target" then
                if event == "UNIT_AURA" then safe(ns.layoutAuras, set.health) end
                safe(ns.layoutBadges, set.health)
            end
        end
    elseif event == "UNIT_HEAL_PREDICTION" then
        fillShown("health")
    elseif event == "PLAYER_TARGET_CHANGED" then
        safe(ns.watchTargetCast, event) -- a new target is not mid-cast until it says so
        safe(Refresh)
    elseif event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        if GetTime() - absorb.castAt <= ABSORB_CAST_WINDOW then -- our cast just put a shield up
            local ok, points = pcall(UnitGetTotalAbsorbs, "player")
            absorb.max, absorb.have = ok and points, ok
        end
        fillShown("absorb")
    elseif event == "UNIT_HEALTH" then
        fillShown("health", "pethealth")
        fillShown("absorb") -- max health scales it
        fillShown("enemyhealth")
    elseif event == "UNIT_POWER_FREQUENT" then
        if unit == "target" then -- only the enemy resource bars read your target's power
            for _, set in ipairs({ frames, plateFrames }) do
                if set.enemyhealth.resFrame:IsShown() then safe(ns.fill, set.enemyhealth.resFrame) end
            end
        else
            fillShown("power", "combo", "druidmana")
        end

    elseif event:find("^UNIT_SPELLCAST_") then
        safe(ns.watchTargetCast, event, unit)
        if unit == "player" then
            safe(fsr.cast, fsr, event, arg2, arg3)
            safe(castCost.track, castCost, event, arg3)
            if event == "UNIT_SPELLCAST_SUCCEEDED" then
                absorb.castAt = GetTime()
                -- Auto Shot or a wand's Shoot: the ranged swing, where no PLAYER_SWING says so
                if ns.swingLog and (arg3 == 75 or arg3 == 5019) then
                    local ok, speed = pcall(UnitRangedDamage, "player")
                    if ok then ns.startSwing(speed, 2) end
                end
            end
        end
        safe(Refresh) -- the cast bar joins or leaves the stack
    elseif event == "PLAYER_SWING" then -- unit, arg2 = duration, swing type
        ns.startSwing(unit, arg2)
    elseif event == "PLAYER_TOTEM_UPDATE" then -- hand the new timers over; they run themselves
        fillShown("totems")
    elseif event == "MERCHANT_SHOW" then
        safe(sellJunk)
        safe(autoRepair)
    elseif event == "MERCHANT_CLOSED" then
        stopSelling()
    elseif event == "QUEST_DETAIL" or event == "QUEST_ACCEPT_CONFIRM" then
        safe(autoAccept, event, unit) -- for QUEST_DETAIL the first arg is the quest-starting item
    elseif event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        safe(autoComplete, event)
    elseif event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then
        safe(npcQuests)
    elseif event == "GOSSIP_CLOSED" then -- walked away: let the same quests be offered again
        C_Timer.After(1, function()
            local busy = (GossipFrame and GossipFrame:IsShown()) or (QuestFrame and QuestFrame:IsShown())
            if not busy then pickedFrom = nil end
        end)
    elseif event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
        safe(questLogChanged)
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat, ns.inCombat = true, true
        safe(Refresh)
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat, ns.inCombat = false, false
        safe(questLogChanged) -- tooltips may have been secret during combat
        safe(Refresh)         -- and protected frames couldn't change
    else
        if event == "NAME_PLATE_UNIT_ADDED" then safe(plateAdded, unit) end
        if event == "NAME_PLATE_UNIT_REMOVED" then safe(plateRemoved, unit) end
        -- form, max, target or nameplate changes: re-layout (target change moves the nameplate bars)
        safe(Refresh)
    end
end)
petEv:SetScript("OnEvent", ev:GetScript("OnEvent"))
listen("ADDON_LOADED")
listen("PLAYER_LOGIN")
