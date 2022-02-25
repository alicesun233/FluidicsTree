function d = rowdist(P)
d = rssq(diff(P,1),2);
