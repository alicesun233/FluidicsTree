function p = perimeter(P)
augP = vertcat(P,P(1,:));
p = sum(rssq(diff(augP,1),2));
