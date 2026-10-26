import Image from "next/image";
import { badges, type Badge } from "../data/site";
import { cn } from "../lib/cn";
import { Link } from "./ui/link";

function BadgeImage({
  src,
  badge,
  className,
}: {
  src: string;
  badge: Badge;
  className?: string;
}) {
  return (
    <Image
      src={src}
      alt={badge.alt}
      width={badge.width}
      height={badge.height}
      className={cn(
        "h-11 w-auto",
        badge.isInvertedInDark && "invert-in-dark",
        className,
      )}
    />
  );
}

export function Badges({ className }: { className?: string }) {
  return (
    <ul className={cn("flex flex-wrap items-center gap-3", className)}>
      {badges.map((badge) => (
        <li key={badge.href}>
          <Link
            href={badge.href}
            className="block opacity-90 transition-opacity hover:opacity-100"
          >
            {badge.darkSrc ? (
              <>
                <BadgeImage
                  src={badge.src}
                  badge={badge}
                  className="light-only"
                />
                <BadgeImage
                  src={badge.darkSrc}
                  badge={badge}
                  className="dark-only"
                />
              </>
            ) : (
              <BadgeImage src={badge.src} badge={badge} />
            )}
          </Link>
        </li>
      ))}
    </ul>
  );
}
